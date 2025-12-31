class SketchAnalysisJob < ApplicationJob
  queue_as :default
  retry_on StandardError, attempts: 3, wait: :exponential

  class ImageAnalysisSchema < RubyLLM::Schema
    object :result do
      string :image_type, description: "The type of the image", enum: %w[photo sketch]
    end
  end

  def perform(canva)
    return unless canva.image.attached?

    # We analyse the image to see if it is a sketch/drawing or a real photo
    # If it is a photo, we proceed as normal
    # If it is a sketch, we update the UI to show the sketch options

    prompt = "Analyze this image and determine if it is a real photo or a sketch/drawing/architecture plan. Return 'photo' or 'sketch'."

    response = CustomRubyLLM.context.chat.with_schema(ImageAnalysisSchema).ask(
      prompt,
      with: canva.image
    )

    result = response.content.dig("result", "image_type")

    if result == "photo"
      canva.update!(treat_as: :photo)
    else
      # If sketch, we don't set treat_as yet. We broadcast to the UI to show the overlay.
      # The UI will subscribe to the turbo stream and show the overlay.
    end

    broadcast_result(canva, result)
    result
  end

  private

  def broadcast_result(canva, result)
    # Replaces the loader with the appropriate content
    # If photo -> standard loader or nothing (as it proceeds)
    # If sketch -> sketch overlay

    if result == "sketch"
       Turbo::StreamsChannel.broadcast_replace_to(
        "canvas_#{canva.id}",
        target: "sketch_overlays",
        partial: "mask_requests/sketch_overlay",
        locals: { canva: canva }
      )
    end
  end
end
