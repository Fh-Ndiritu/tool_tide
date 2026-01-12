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

    payload = gcp_payload(prompt: prompt, image: input_image)
    response = fetch_gcp_response(payload)
    blob = save_gcp_results(response)

    @layer.result_image.attach(blob)
  rescue StandardError => e
    Rails.logger.error("ProjectGenerator: #{e.message}")
    raise e
  end

  private

  def construct_prompt
    prompts_config = YAML.load_file(Rails.root.join("config/prompts.yml"))
    base = if @layer.preset.present?
      load_preset_prompt(@layer.preset, prompts_config)
    else
      @layer.prompt
    end
    add_system_instructions(base)
  end

  def load_preset_prompt(preset, config)
    config.dig("landscape_presets", preset) || config.dig("landscape_preference_presets", preset)
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
end
