class SketchGenerationJob < ApplicationJob
  queue_as :default
  include Designable

  def perform(sketch_request)
    # 1. Clay Rendering
    binding.irb
    sketch_request.update!(progress: :processing_clay)
    generate_view(sketch_request, :clay_view, "clay_render", sketch_request.canva.image)

    # 2. Architectural Rendering
    sketch_request.update!(progress: :processing_archi)
    input_image = sketch_request.clay_view.attached? ? sketch_request.clay_view : sketch_request.canva.image
    generate_view(sketch_request, :archi_view, "architectural_render", input_image)

    # 3. Photorealistic Rendering
    sketch_request.update!(progress: :processing_photo)
    input_image = sketch_request.archi_view.attached? ? sketch_request.archi_view : sketch_request.canva.image
    generate_view(sketch_request, :photo_view, "photorealistic_render", input_image)

    sketch_request.update!(progress: :complete)

  rescue => e
    Rails.logger.error("SketchGenerationJob Failure: #{e.message}")
    SketchPipelineService.refund_on_failure(sketch_request) unless sketch_request.clay_view.attached?
    sketch_request.update!(progress: :failed, error_msg: e.message)
  end

  private

  def generate_view(sketch_request, attachment_name, prompt_key, input_image)
    prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("sketch_transformation", prompt_key)

    payload = gcp_payload(prompt: prompt, image: input_image)
    response = fetch_gcp_response(payload)

    blob = save_gcp_results(response)

    if blob
      sketch_request.public_send(attachment_name).attach(blob)
    else
      raise "Failed to generate image for #{prompt_key}"
    end
  end
end
