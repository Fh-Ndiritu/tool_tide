class SketchAnalysisJob < ApplicationJob
  queue_as :default
  retry_on StandardError, attempts: 3

  class ImageAnalysisSchema < RubyLLM::Schema
    object :result do
      string :image_type, description: "The type of the image", enum: %w[photo sketch satellite]
    end
  end

  def perform(canva)
    return unless canva.image.attached?

    # We analyse the image to see if it is a sketch/drawing, a satellite image or a real photo
    # If it is a photo, we proceed as normal
    # If it is a sketch or satellite, we update the UI to show the notification

    prompt = "Analyze this image and determine if it is a real photo, a sketch/drawing/architecture plan, or a satellite/aerial map view. Return 'photo', 'sketch' or 'satellite'."

    response = CustomRubyLLM.context.chat.with_schema(ImageAnalysisSchema).ask(
      prompt,
      with: canva.image
    )

    result = response.content.dig("result", "image_type")

    if result == "photo"
      canva.update!(treat_as: :photo)
    else
      # If sketch or satellite, we just broadcast to the UI to show the notification.
      # The UI will subscribe to the turbo stream and show the overlay.
    end

    broadcast_result(canva, result)
    result
  end

  private

  def broadcast_result(canva, result)
    # Replaces the loader with the appropriate content
    # If photo -> standard loader or nothing (as it proceeds)
    # If sketch/satellite -> notification overlay

    if %w[sketch satellite].include?(result)
       Turbo::StreamsChannel.broadcast_update_to(
        canva,
        target: "sketch_notification_container",
        partial: "mask_requests/sketch_notification",
        locals: { canva: canva, result: result }
      )
    end
  end
end
