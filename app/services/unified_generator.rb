class UnifiedGenerator
  include Designable

  attr_reader :layer

  def initialize(layer)
    @layer = layer
  end

  def self.perform(layer_id)
    new(ProjectLayer.find(layer_id)).generate
  end

  def generate
    full_prompt = construct_prompt

    input_image = prepare_input_image

    return if input_image.blank?

    payload = gcp_payload(prompt: full_prompt, image: input_image)
    response = fetch_gcp_response(payload)


    blob = save_gcp_results(response)
    if blob
      layer.image.attach(blob)
    else
      Rails.logger.error("UnifiedGenerator: Failed to save GCP results for layer #{layer.id}")
    end
  end

  private

  def construct_prompt
    # Exclusive: Preset OR Custom Prompt
    if layer.preset.present?
      prompt_text = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("landscape_presets", layer.preset)
      # If preset prompt is missing, fallback or error.
      prompt_text || layer.prompt
    else
      layer.prompt
    end
  end

  def prepare_input_image
    # If the layer itself has an attached mask, we use the parent as base and overlay the mask.
    if layer.mask.attached?
      parent = layer.parent_layer || layer.project.layers.layer_type_original.first
      return layer.mask unless parent&.image&.attached?

      blob = apply_mask_overlay(mask: layer.mask, background: parent)
      layer.mask_overlay.attach(blob)
      layer.mask_overlay
    else
      # Fallback to parent image if no mask
      layer.parent_layer&.image
    end
  end

  def apply_mask_overlay(mask:, background:)
    # Download images
    bg_image = MiniMagick::Image.read(background.image.download)
    mask_image = MiniMagick::Image.read(mask.download)

    # Ensure sizes match
    unless bg_image.dimensions == mask_image.dimensions
      mask_image.resize "#{bg_image.width}x#{bg_image.height}!"
    end

    # Process Mask: Make white transparent (as per MaskRequest logic)
    mask_image.combine_options do |c|
      c.fuzz "10%"
      c.transparent "white"
    end

    # Composite the mask over the background image
    masked_image = bg_image.composite(mask_image) do |c|
      c.compose "Over"
      c.gravity "Center"
    end

    # Use upload_blob from Designable to save the resulting composite
    upload_blob(masked_image)
  end
end
