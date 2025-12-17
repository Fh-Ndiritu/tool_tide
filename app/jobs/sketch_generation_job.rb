class SketchGenerationJob < ApplicationJob
  queue_as :default
  include Designable

  class SketchAnalysisSchema < RubyLLM::Schema
    object :response do
      string :analysis, description: "A detailed description of the architectural style and features of the sketch."
      string :angle, description: "The recommended camera angle for a 3D render (e.g. 'Eye Level', 'Aerial', 'Slight Rotation')."
    end
  end

  def perform(sketch_request)
    # 1. Architectural View (ArchiCAD / White Mode)
    sketch_request.update!(progress: :processing_architectural)
    archi_prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("sketch_transformation", "archi_cad_render")
    generate_view(sketch_request, :architectural_view, archi_prompt, sketch_request.canva.image)

    if !sketch_request.architectural_view.attached?
      sketch_request.update!(progress: :failed, error_msg: "Failed to generate Architectural View")
      return
    end
    # 2. 3D Photo Mode (Photorealistic)
    # Stored in :photorealistic_view
    sketch_request.update!(progress: :processing_photorealistic)
    prompt_text = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("sketch_transformation", "photorealistic_render")
    prompt_text = prompt_text.gsub("<<analysis>>", sketch_request.analysis) if sketch_request.analysis.present?
    generate_view(sketch_request, :photorealistic_view, prompt_text, sketch_request.architectural_view)

    # 3. Recommended Angle (Rotated)
    # Stored in :rotated_view
    sketch_request.update!(progress: :processing_rotated)
    angle_prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("sketch_transformation", "angle_transformation")

    # Input is the Photorealistic result (photorealistic_view)
    generate_view(sketch_request, :rotated_view, angle_prompt, sketch_request.photorealistic_view)

    sketch_request.update!(progress: :complete)

  rescue => e
    Rails.logger.error("SketchGenerationJob Failure: #{e.message}")
    pp e.backtrace
    # Refund no longer needed as we don't charge upfront
    sketch_request.update!(
      progress: :failed,
      error_msg: e.message,
      user_error: "We couldn't generate your 3D model. Please try again or use a different image."
    )
  end

  private

  def generate_view(sketch_request, attachment_name, prompt_text, input_image)
    # prompt_text is now passed directly, not a key

    payload = gcp_payload(prompt: prompt_text, image: input_image)
    response = fetch_gcp_response(payload)

    blob = save_gcp_results(response)

    if blob
      sketch_request.public_send(attachment_name).attach(blob)
    else
      raise "Failed to generate image for step #{attachment_name}"
    end

    if attachment_name == :architectural_view
      sketch_request.update!(analysis: response.dig("candidates", 0, "content", "parts", 0, "text"))
    end
  end
end
