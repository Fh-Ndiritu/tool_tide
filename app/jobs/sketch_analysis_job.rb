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
    message = "⚠️ **Sketch/Satellite Detected**\n\n" \
              "**User:** #{user.email} (ID: #{user.id})\n" \
              "**Record Type:** #{record.class.name}\n" \
              "**Record ID:** #{record.id}\n" \
              "**Detected Type:** #{result}"

    # Use service_url if available for public access, otherwise url
    image_url = record.image.attached? ? record.image.url : nil

    # Telegram cannot access localhost, so we skip the image in that case and send text only
    if image_url && (image_url.include?("localhost") || image_url.include?("127.0.0.1"))
      image_url = nil
    end

    TelegramNotifier::Dispatcher.new.dispatch(message, image_url: image_url)
  rescue StandardError => e
    Rails.logger.error("Failed to send Telegram notification: #{e.message}")
  end

  def broadcast_result(record, result)
    # Replaces the loader with the appropriate content
    # If photo -> standard loader or nothing (as it proceeds)
    # If sketch/satellite -> notification overlay

    return unless %w[sketch satellite].include?(result)

    if record.is_a?(Canva)
       Turbo::StreamsChannel.broadcast_update_to(
        record,
        target: "sketch_notification_container",
        partial: "mask_requests/sketch_notification",
        locals: { canva: record, result: result }
      )
    elsif record.is_a?(ProjectLayer)
        Turbo::StreamsChannel.broadcast_append_to(
          [record.design, :layers],
          target: "project_notifications",
          partial: "project_layers/sketch_notification",
          locals: { result: result, project_layer: record }
        )
    end
  end
end
