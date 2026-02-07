class SketchAnalysisJob < ApplicationJob
  queue_as :default
  retry_on StandardError, attempts: 3

  class ImageAnalysisSchema < RubyLLM::Schema
    object :result do
      string :image_type, description: "The type of the image", enum: %w[photo sketch satellite]
    end
  end

  def perform(record)
    return unless record.image.attached?
    return unless record.image.content_type.start_with?("image/")

    # We analyse the image to see if it is a sketch/drawing, a satellite image or a real photo
    # If it is a photo, we proceed as normal
    # If it is a sketch or satellite, we update the UI to show the notification

    prompt = "Analyze this image and determine if it is a real photo, a sketch/drawing/architecture plan, or a satellite/aerial map view. Return 'photo', 'sketch' or 'satellite'."

    response = CustomRubyLLM.context.chat.with_schema(ImageAnalysisSchema).ask(
      prompt,
      with: record.image
    )

    result = response.content.dig("result", "image_type")

    if result == "photo"
      record.update!(treat_as: :photo) if record.respond_to?(:treat_as)
    else
      # If sketch or satellite, we just broadcast to the UI to show the notification.
      # The UI will subscribe to the turbo stream and show the overlay.
      notify_telegram(record, result)
    end

    broadcast_result(record, result)
    result
  end

  private

  def notify_telegram(record, result)
    user = record.user
    message = <<~MESSAGE
      ⚠️ **Sketch/Satellite Detected**

      **User:** #{user&.name}
      **User ID:** #{user&.id}
      **User Email:** #{user&.email}


      **Record Type:** #{record.class.name}
      **Record ID:** #{record.id}
      **Detected Type:** #{result}
    MESSAGE


    # Use service_url if available for public access, otherwise url
    # Upload image directly to Telegram to avoid URL access issues
    image_io = if record.image.attached?
      # Resize to max 400x400 to save bandwidth and avoid payload limits
      variant = record.image.variant(resize_to_limit: [ 400, 400 ]).processed
      StringIO.new(variant.download)
    end

    TelegramNotifier::Dispatcher.new.dispatch(message, image_io: image_io)
  rescue StandardError => e
    Rails.logger.error("Failed to send Telegram notification: #{e.message}")
  end

  def broadcast_result(record, result)
    # Replaces the loader with the appropriate content
    # If photo -> standard loader or nothing (as it proceeds)
    # If sketch/satellite -> notification overlay

    return unless %w[sketch satellite].include?(result)

    # Persist the detection result if possible
    record.update(detected_type: result) if record.respond_to?(:detected_type)

    if record.is_a?(Canva)
       Turbo::StreamsChannel.broadcast_update_to(
        record,
        target: "sketch_notification_container",
        partial: "mask_requests/sketch_notification",
        locals: { canva: record, result: result }
      )
    elsif record.is_a?(ProjectLayer)
        # We rely on the record update triggering a refresh of the page/design
        # which will then render the notification and the correct tab button state in show.html.erb

        # Explicitly broadcast to update the tab button just in case the refresh is slow or partial
        Turbo::StreamsChannel.broadcast_replace_to(
          record.project,
          target: "tab_sketch_container",
          partial: "projects/tools/sketch_tab_button",
          locals: { project: record.project, active_layer: record }
        )
    end
  end
end
