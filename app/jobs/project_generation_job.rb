class ProjectGenerationJob < ApplicationJob
  class InsufficientCreditsError < StandardError; end
  queue_as :generation
  limits_concurrency to: 5, key: ->(*) { "generation" }

  retry_on StandardError, wait: 3.seconds, attempts: 3 do |job, error|
    raise error if error.is_a?(InsufficientCreditsError)
  end

  # When retries are exhausted, refund the user
  # We do not need tries on low credits errors
  discard_on StandardError do |job, error|
    if error.is_a?(InsufficientCreditsError)
      layer_id = job.arguments.first
      layer = ProjectLayer.find_by(id: layer_id)
      next unless layer

      layer.update!(
        progress: :failed,
        error_msg: error.message,
        user_msg: "Insufficient credits. Please top up to continue."
      )
      job.send(:notify_telegram, error, layer)
    else
      job.send(:handle_final_failure, error)
    end
    next
  end

  def perform(layer_id)
    layer = ProjectLayer.find(layer_id)

    # Guard: Check if layer was cancelled before we start
    layer.with_lock do
      return if layer.failed? || layer.complete?
      layer.processing!
    end

    user = layer.project.user
    cost = if layer.generation_type == "upscale"
             GOOGLE_UPSCALE_COST
    else
             MODEL_COST_MAP[layer.model] || GOOGLE_PRO_IMAGE_COST
    end

    charge_user!(user, layer, cost)

    # Guard: Check again after charging in case cancelled during wait
    return if layer.reload.failed?

    layer.generating!
    broadcast_update(layer)

    has_mask = ProjectOverlayGenerator.perform(layer)

    if layer.ai_assist?
      SmartFixImprover.perform(layer, has_mask: has_mask)
    end

    ProjectGeneratorService.perform(layer)

    # Guard: Don't overwrite 'failed' status if cancelled during generation
    layer.with_lock do
      return if layer.failed?
      layer.complete!
    end

    # Post-generation storage optimizations
    downsize_overlay!(layer)
    purge_mask!(layer)

    broadcast_update(layer)
  end

  private

  def charge_user!(user, layer, cost)
    user.with_lock do
      # Check if layer was cancelled while waiting for lock
      if layer.reload.failed?
        Rails.logger.info("Skipping charge for layer #{layer.id} - cancelled by user")
        return
      end

      if user.pro_engine_credits < cost
        raise InsufficientCreditsError, "Insufficient credits"
      end

      user.pro_engine_credits -= cost
      user.save!

      CreditSpending.create!(
        user: user,
        amount: cost,
        transaction_type: :spend,
        trackable: layer
      )
    end
  end

  def handle_final_failure(error)
    layer_id = arguments.first
    layer = ProjectLayer.find_by(id: layer_id)
    return unless layer

    user = layer.project.user
    cost = if layer.generation_type == "upscale"
             GOOGLE_UPSCALE_COST
    else
             MODEL_COST_MAP[layer.model] || GOOGLE_PRO_IMAGE_COST
    end

    Rails.logger.error("ProjectGenerationJob Failed permanently: #{error.message}")

    # Check charge status and handle refund inside lock
    user.with_lock do
      has_been_charged = CreditSpending.exists?(
        user: user,
        trackable: layer,
        transaction_type: :spend
      )

      if has_been_charged
        # Refund the user
        user.pro_engine_credits += cost
        user.save!
        CreditSpending.create!(
          user: user,
          amount: cost,
          transaction_type: :refund,
          trackable: layer
        )
      else
        Rails.logger.info("Skipping refund for layer #{layer.id} - User was not charged.")
      end
    end

    # Always mark layer as failed (outside the lock)
    layer.update(progress: :failed, error_msg: error.message)
    broadcast_update(layer)
    notify_telegram(error, layer)
  end

  def notify_telegram(error, layer)
    user = layer.project.user
    message = "❌ **Project Generation Error**\n\n" \
              "**User:** #{user.email} (ID: #{user.id})\n" \
              "**Layer ID:** #{layer.id}\n" \
              "**Error Type:** #{error.class.name}\n" \
              "**Message:** #{error.message}\n" \
              "**Prompt:** #{layer.prompt&.truncate(100) || 'N/A'}"

    TelegramNotifier::Dispatcher.new.dispatch(message)
  rescue StandardError => e
    Rails.logger.error("Failed to send Telegram notification: #{e.message}")
  end

  def downsize_overlay!(layer)
    return unless layer.overlay.attached?
    return if layer.overlay.blob.byte_size < 100_000 # Already small

    variant = layer.overlay.variant(resize_to_limit: [ 400, 400 ]).processed
    layer.overlay.attach(
      io: StringIO.new(variant.download),
      filename: "overlay_thumb.webp",
      content_type: "image/webp"
    )
  rescue => e
    Rails.logger.warn("Overlay downsize failed for layer #{layer.id}: #{e.message}")
  end

  def purge_mask!(layer)
    return unless layer.mask.attached? && layer.overlay.attached?

    layer.mask.purge
  rescue => e
    Rails.logger.warn("Mask purge failed for layer #{layer.id}: #{e.message}")
  end

  def broadcast_update(layer)
    # Using Turbo Streams to update the layer row
    Turbo::StreamsChannel.broadcast_replace_to(
      layer.project, :layers,
      target: "layer_#{layer.id}",
      partial: "project_layers/project_layer",
      locals: { project_layer: layer }
    )
  end
end
