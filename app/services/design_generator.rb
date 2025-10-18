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

    array :other_features, description: "A markdown list of a description other features to include. Keep it concise" do
      string :feature_description
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

    suggest_plants
    main_view

    generate_secondary_views

    @mask_request.processed!
    charge_generation

  rescue Faraday::ServerError => e
    user_error = e.is_a?(Faraday::ServerError) ? "We are having some downtime, try again later ..." : "Something went wrong, try a different style."
    @mask_request.update error_msg: e.message, progress: :failed, user_error:
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

  def suggest_plants
    @mask_request.plants!
    prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("image_analysis", "general")
    prompt.gsub!("<<style>>", @mask_request.preset.capitalize)
    response = RubyLLM.chat.with_schema(GardenFeatureSchema).ask(prompt, with: @mask_request.overlay)

    ActiveRecord::Base.transaction do
      data = response.content["design_features"]
      data["plants"].map do |plant_data|
        Plant.find_or_initialize_by(english_name: plant_data["english_name"]).tap do |plant_record|
          plant_record.assign_attributes(plant_data.except("english_name", "quantity"))

          plant_record.save!
          @mask_request.mask_request_plants.destroy_all
          MaskRequestPlant.create(plant: plant_record, mask_request_id: @mask_request.id, quantity: plant_data["quantity"])
        end
      end

      @mask_request.update!(features: data["other_features"])
    end
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
