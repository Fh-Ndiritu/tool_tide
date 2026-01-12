class ProjectGenerationJob < ApplicationJob
  class InsufficientCreditsError < StandardError; end
  queue_as :default

  retry_on StandardError, attempts: 3 do |job, error|
    raise error if error.is_a?(InsufficientCreditsError)
  end

  # When retries are exhausted, refund the user
  # We do not need tries on low credits errors
  discard_on StandardError do |job, error|
    job.send(:handle_final_failure, error) unless error.is_a?(InsufficientCreditsError)
  end

  def perform(layer_id)
    layer = ProjectLayer.find(layer_id)
    user = layer.project.user
    cost = GOOGLE_IMAGE_COST

    charge_user!(user, layer, cost)
    layer.update!(progress: :processed)
    layer.main_view!
    broadcast_update(layer)

    has_mask = ProjectOverlayGenerator.perform(layer)

    if layer.ai_assist?
      SmartFixImprover.perform(layer, has_mask: has_mask)
    end

    ProjectGeneratorService.perform(layer)

    layer.complete!
    broadcast_update(layer)
  end

  private

  def charge_user!(user, layer, cost)
    user.with_lock do
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
    cost = GOOGLE_IMAGE_COST # Should ideally be passed or stored?
    # For now constant is fine as long as prices don't change dynamically mid-job.

    Rails.logger.error("ProjectGenerationJob Failed permanently: #{error.message}")

    user.with_lock do
      user.pro_engine_credits += cost
      user.save!
      CreditSpending.create!(
        user: user,
        amount: cost,
        transaction_type: :refund,
        trackable: layer
      )
    end

    layer.update(progress: :failed)
    broadcast_update(layer)
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
