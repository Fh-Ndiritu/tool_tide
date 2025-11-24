class GardenFeatureSchema < RubyLLM::Schema
  object :design_features do
    array :plants, description: "A list of all plants to be used in the garden." do
      object do
        string :english_name, description: "The common name of the plant."
        string :description, description: "Description of the plant's colors, flowering, and overall look."
        integer :quantity, description: "The total number of this specific plant needed."
        string :size, description: "The estimated height and width when fully grown (e.g., '15 * 10 ft')."
      end
    end

    string :other_features, description: "A markdown unordered list of a description other design features to include."
  end
end

class PlantDetailsSchema < RubyLLM::Schema
  object :plant_details do
    string :description, description: "Description of the plant's colors, flowering season, and overall look."
    string :size, description: "The estimated height and width when fully grown (e.g., '15 * 10 ft')."
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

    suggest_plants(force: false)
    validate_plants
    main_view

    generate_secondary_views

    @mask_request.processed!
    charge_generation

  rescue Faraday::ServerError => e
    user_error = e.is_a?(Faraday::ServerError) ? "We are having some downtime, try again later ..." : "Something went wrong, try a different style."
    @mask_request.update error_msg: e.message, progress: :failed, user_error:
  end

  def suggest_plants(force: false)
    @mask_request.plants!
    return if !force && @mask_request.mask_request_plants.any?

    ActiveRecord::Base.transaction do
      @mask_request.mask_request_plants.destroy_all
      prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("image_analysis", "general")
      prompt.gsub!("<<style>>", @mask_request.preset.capitalize)

      user = @mask_request.canva.user
      if user.latitude.present? && user.longitude.present?
        location_info = "The garden is located at coordinates #{user.latitude}, #{user.longitude}."
        location_info += " Address: #{user.address['formatted_address']}" if user.address.present? && user.address["formatted_address"].present?
        prompt += "\n\n#{location_info}\nSuggest plants suitable for this specific location and climate."
      end

      response = RubyLLM.chat.with_schema(GardenFeatureSchema).ask(prompt, with: @mask_request.overlay)


      data = response.content["design_features"]

      data["plants"].each do |plant_data|
        # Only save plant name, no details yet (validated: false)
        plant = Plant.find_or_create_by!(english_name: plant_data["english_name"])
        MaskRequestPlant.create!(plant: plant, mask_request_id: @mask_request.id, quantity: plant_data["quantity"])
      end

      @mask_request.update!(features: data["other_features"])
    end
  end

  def validate_plants
    # Get all unvalidated plants for this mask request
    unvalidated_plants = @mask_request.mask_request_plants.joins(:plant).where(plants: { validated: false })

    unvalidated_plants.each do |mrp|
      plant = mrp.plant

      begin
        details = fetch_plant_details(plant.english_name)

        # Check if LLM returned valid details
        if details && details["description"].present? && details["size"].present?
          plant.update!(
            description: details["description"],
            size: details["size"],
            validated: true
          )
        else
          # Plant not found or invalid, keep validated: false
          Rails.logger.warn("Could not validate plant: #{plant.english_name}")
        end
      rescue => e
        # Handle any errors gracefully, keep plant as unvalidated
        Rails.logger.error("Error validating plant #{plant.english_name}: #{e.message}")
      end
    end
  end

  def fetch_plant_details(plant_name)
    prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("image_analysis", "single_plant")
    prompt.gsub!("<<plant_name>>", plant_name)

    response = RubyLLM.chat.with_schema(PlantDetailsSchema).ask(prompt)
    response.content["plant_details"]
  end

  private

  def main_view
    @mask_request.main_view!
    prompt = if @mask_request.feature_prompt.present?
      prompt_wrapper = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("image_analysis", "wrapper")
      prompt_wrapper.gsub!("<<feature_prompt>>", @mask_request.feature_prompt)
      prompt_wrapper.gsub!("<<style>>", @mask_request.preset)

      plants = @mask_request.mask_request_plants.map { |mp|  [ mp.quantity, mp.plant.english_name, "( #{mp.plant.description})" ].join(" ") }.join("\n")
      prompt_wrapper.gsub!("<<plants>>", plants)
       prompt_wrapper.gsub!("<<other_features>>", @mask_request.features)
    else
     @mask_request.prompt
    end

    image = @mask_request.overlay
    payload = gcp_payload(prompt:, image:)
    response = fetch_gcp_response(payload)
    blob = save_gcp_results(response)
    @mask_request.main_view.attach(blob)
  end


  def generate_secondary_views
    @mask_request.rotating!
    rotate_view

    @mask_request.drone!
    drone_view
  rescue StandardError => e
    @mask_request.update error_msg: e.message
  end

  def rotate_view
    image = @mask_request.reload.main_view
    return unless  image.attached?

    payload = gcp_payload(prompt: rotated_landscape_prompt, image:)
    response = fetch_gcp_response(payload)
    blob = save_gcp_results(response)
    @mask_request.rotated_view.attach(blob)
  end

  def drone_view
    image = @mask_request.reload.rotated_view
    return unless image.attached?

    payload = gcp_payload(prompt: aerial_landscape_prompt, image:)
    response = fetch_gcp_response(payload)
    blob = save_gcp_results(response)
    @mask_request.drone_view.attach(blob)
  end
end
