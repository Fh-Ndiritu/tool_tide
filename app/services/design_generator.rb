class GardenSuggestionSchema < RubyLLM::Schema
  array :plants, description: "A list of all plants to be used in the garden, with detailed planting and maintenance instructions." do
    object do
      string :english_name, description: "The common name of the plant."
      string :description, description: "Brief guide including planting instructions, maintenance requirements, and visual description."
      integer :quantity, description: "The total number of this specific plant needed."
      string :size, description: "The estimated height and width when fully grown (e.g., '15 * 10 ft')."
    end
  end
end

class DesignGenerator
  include Designable

  def initialize(mask_request)
    @mask_request = mask_request
  end

  def self.perform(*args)
    new(*args).generate
  end

  def generate
    @mask_request.update user_error: nil, error_msg: nil, progress: :preparing
    @mask_request.purge_views

    unless @mask_request.overlay.attached?
      @mask_request.resize_mask

      @mask_request.overlaying!
      @mask_request.overlay_mask
    end

    main_view

    # Variations are now generated within main_view

    charge_generation

  rescue Faraday::ServerError => e
    user_error = e.is_a?(Faraday::ServerError) ? "We are having some downtime, try again later ..." : "Something went wrong, try a different style."
    @mask_request.update error_msg: e.message, progress: :failed, user_error:
  end

  def generate_planting_guide
    ActiveRecord::Base.transaction do
      @mask_request.mask_request_plants.destroy_all
      prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("plant_detection")
      response = CustomRubyLLM.context.chat.with_schema(GardenSuggestionSchema).ask(prompt, with: @mask_request.main_view)
      plants = response.content["plants"]

      plants.each do |plant_data|
        plant = Plant.find_or_create_by!(english_name: plant_data["english_name"])
        plant.update!(
          description: plant_data["description"],
          size: plant_data["size"],
          validated: true
        )
        MaskRequestPlant.create!(plant: plant, mask_request_id: @mask_request.id, quantity: plant_data["quantity"])
      end
    end
    @mask_request.complete!
  end

  private

  def main_view
    @mask_request.main_view!
    prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("landscape_presets", @mask_request.preset)

    prompt += "
    YOU SHALL include the image in your response!
    DO NOT modify any other areas of the image except for the precise region marked by violet paint.
    YOU CANNOT MODIFY the HOUSES, ADD new HOUSES or REMOVE the houses.
    ONLY MODIFY the precise region marked by violet paint.
    "

    image = @mask_request.overlay

    # Generate Option 1 (Main View)
    payload = gcp_payload(prompt:, image:)
    response = fetch_gcp_response(payload)
    blob = save_gcp_results(response)
    @mask_request.main_view.attach(blob)

    # Generate Option 2 (Stored in rotated_view)
    @mask_request.rotating!
    response = fetch_gcp_response(payload) # Same payload
    blob = save_gcp_results(response)
    @mask_request.rotated_view.attach(blob)

    # Generate Option 3 (Stored in drone_view)
    @mask_request.drone!
    response = fetch_gcp_response(payload) # Same payload
    blob = save_gcp_results(response)
    @mask_request.drone_view.attach(blob)

    @mask_request.processed!
  rescue StandardError => e
    @mask_request.update error_msg: e.message
  end
end
