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
    # 0. Analysis & Strategy
    sketch_request.update!(progress: :processing_architectural) # Start with first stage

    analysis_prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("sketch_analysis", "general")

    # Analyze the sketch
    # We use Flash for fast analysis - RubyLLM should handle model selection or default
    begin
      response = RubyLLM.chat.with_schema(SketchAnalysisSchema).ask(
        analysis_prompt,
        with: sketch_request.canva.image
      )

      # Parse JSON
      result = response.content["response"]
      sketch_request.update!(
        analysis: result["analysis"],
        recommended_angle: result["angle"]
      )
    rescue => e
      Rails.logger.error "Analysis Parse Error: #{e.message}"
      # Fallback defaults
      sketch_request.update!(
        analysis: "A modern architectural structure with clean lines and a garden.",
        recommended_angle: "Slight Rotation to Right"
      )
    end

    # 1. Architectural View (ArchiCAD / White Mode)
    # Stored in :architectural_view
    archi_prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("sketch_transformation", "archi_cad_render")
    archi_prompt = archi_prompt.gsub("<<analysis>>", sketch_request.analysis)

    generate_view(sketch_request, :architectural_view, archi_prompt, sketch_request.canva.image)

    # 2. 3D Photo Mode (Photorealistic)
    # Stored in :photorealistic_view
    sketch_request.update!(progress: :processing_photorealistic)

    photo_prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("sketch_transformation", "photorealistic_render")
    # Using the ArchiCAD view (architectural_view) as input for clean structure
    generate_view(sketch_request, :photorealistic_view, photo_prompt, sketch_request.architectural_view)

    # 3. Recommended Angle (Rotated)
    # Stored in :rotated_view
    sketch_request.update!(progress: :processing_rotated)
    angle_prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("sketch_transformation", "angle_transformation")
    angle_prompt = angle_prompt.gsub("<<angle>>", sketch_request.recommended_angle)

    # Input is the Photorealistic result (photorealistic_view)
    generate_view(sketch_request, :rotated_view, angle_prompt, sketch_request.photorealistic_view)

    sketch_request.update!(progress: :complete)

  rescue => e
    Rails.logger.error("SketchGenerationJob Failure: #{e.message}")
    pp e.backtrace
    SketchPipelineService.refund_on_failure(sketch_request) unless sketch_request.architectural_view.attached?
    sketch_request.update!(progress: :failed, error_msg: e.message)
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
  end
end
