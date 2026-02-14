class ProjectGeneratorService
  include Designable

  def initialize(project_layer)
    @layer = project_layer
  end

  def self.perform(project_layer)
    new(project_layer).generate
  end

  def generate
    prompt = construct_prompt

    # Resolve the input image (Overlay of Base + Mask)
    # For now, we assume standard Inpainting flow where we send a masked image.
    # We need to construct this overlay if it doesn't exist.
    # Unlike MaskRequest, ProjectLayer acts as the container.
    # We will assume `layer.project.user` context for cost? (Already handled in Job).

    # TODO: Implement `overlay` logic similar to DesignGenerator if needed.
    # For now, simplistic fetch.

    input_image = resolve_input_image

    config = {}
    if @layer.generation_type == "upscale"
      config = {
        "generationConfig" => {
          "responseModalities" => [ "TEXT", "IMAGE" ],
          "imageConfig" => { "imageSize" => "4K" }
        }
      }
    end

    payload = gcp_payload(prompt: prompt, image: input_image, config: config)

    # Use MODEL_NAME_MAP to get the real model name from the alias
    # Standard Mode -> "gemini-2.5-flash-image"
    # Pro Mode -> "gemini-2.5-flash-image" (fallback)
    # Note: Sketch transforms use SKETCH_TRANSFORM_MODEL via the Agentic tools, not this service.
    actual_model = MODEL_NAME_MAP[@layer.model] || MODEL_NAME_MAP[MODEL_ALIAS_PRO]

    response = fetch_gcp_response(payload, model: actual_model)
    blob = save_gcp_results(response)

    @layer.result_image.attach(convert_to_webp(blob))
  rescue StandardError => e
    Rails.logger.error("ProjectGenerator: #{e.message}")
    raise "ProjectGenerator Failed: #{e.message}"
  end

  private

  def construct_prompt
    return "Upscale this image to 4k resolution." if @layer.generation_type == "upscale"

    prompts_config = YAML.load_file(Rails.root.join("config/prompts.yml"))
    base = if @layer.preset.present?
      load_preset_prompt(@layer.preset, prompts_config)
    else
      @layer.prompt
    end
    add_system_instructions(base)
  end

  def load_preset_prompt(preset, config)
    prompt = config.dig("projects", "presets", preset)
    if prompt
      "Your task is to turn the area masked in violet into a #{preset} landscape design.
      You SHALL NOT modify anything outside the AREA MASKED IN VIOLET.
      When the user has highlighted multiple areas, you need to treat them as separate areas and design each one independently without the unmasked regions between them.

      The user wants to apply a #{preset} landscape design to this area.

      Start by counting the number of violet masked areas.

      " + prompt
    end
  end

  def add_system_instructions(prompt)
    prompt + "\nYOU SHALL include the image in your response!\nONLY MODIFY the precise region marked by violet paint."
  end

  def resolve_input_image
    # Prefer generated overlay which includes mask composition
    return @layer.overlay if @layer.overlay.attached?

    # Fallback to parent result or image (Maskless Stub)
    @layer.parent&.result_image || @layer.parent&.image
  end

  def convert_to_webp(blob)
    return blob unless blob

    img = MiniMagick::Image.read(blob.download)
    img.format "webp"

    io = StringIO.new(img.to_blob)
    ActiveStorage::Blob.create_and_upload!(
      io: io,
      filename: "result_image.webp",
      content_type: "image/webp"
    )
  rescue => e
    Rails.logger.warn("WebP conversion failed: #{e.message}, using original")
    blob
  end
end
