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

class PlantDetailsListSchema < RubyLLM::Schema
  object :plants_details do
    array :plants, description: "List of details for each plant." do
      object do
        string :english_name, description: "The common name of the plant (must match input)."
        string :description, description: "Description of the plant's colors, flowering season, and overall look."
        string :size, description: "The estimated height and width when fully grown (e.g., '15 * 10 ft')."
        integer :quantity, description: "The recommended quantity for this plant in the garden."
      end
    end
  end
end

class GardenSuggestionSchema < RubyLLM::Schema
  object :design_features do
    array :plants, description: "A list of suggested plants." do
      object do
        string :english_name, description: "The common name of the plant."
      end
    end

    string :other_features, description: "A markdown unordered list of a description other design features to include."
  end
end

class SketchDetectionSchema < RubyLLM::Schema
  object :analysis do
    boolean :is_sketch, description: "True if the image is an architectural sketch, drawing, or blueprint. False otherwise."
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

    suggest_plants(force: false)
    validate_plants

    if detect_sketch
      generate_sketch_pipeline
    else
      unless @mask_request.overlay.attached?
        @mask_request.resize_mask

        @mask_request.overlaying!
        @mask_request.overlay_mask
      end
      main_view
      generate_secondary_views
    end

    charge_generation if @mask_request.canva.user.afford_generation?

  rescue Faraday::ServerError => e
    user_error = e.is_a?(Faraday::ServerError) ? "We are having some downtime, try again later ..." : "Something went wrong, try a different style."
    @mask_request.update error_msg: e.message, progress: :failed, user_error:
  end

  def suggest_plants(force: false)
    @mask_request.plants!
    return if !force && @mask_request.mask_request_plants.any?

    ActiveRecord::Base.transaction do
      @mask_request.mask_request_plants.destroy_all
      prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("image_analysis", "plant_suggestions_only")
      prompt.gsub!("<<style>>", @mask_request.preset.capitalize)

      user = @mask_request.canva.user
      if user.latitude.present? && user.longitude.present?
        location_info = "The garden is located at coordinates #{user.latitude}, #{user.longitude}."
        location_info += " Address: #{user.address['formatted_address']}" if user.address.present? && user.address["formatted_address"].present?
        prompt += "\n\n#{location_info}\nSuggest plants suitable for this specific location and climate."
      end

      response = RubyLLM.chat.with_schema(GardenSuggestionSchema).ask(prompt, with: @mask_request.overlay)


      data = response.content["design_features"]

      data["plants"].each do |plant_data|
        # Only save plant name, no details yet (validated: false)
        plant = Plant.find_or_create_by!(english_name: plant_data["english_name"])
        # Quantity will be set during validation
        MaskRequestPlant.create!(plant: plant, mask_request_id: @mask_request.id, quantity: 1)
      end

      @mask_request.update!(features: data["other_features"])
    end
  end

  def validate_plants
    # Get all plants for this mask request (both suggested and custom)
    mask_request_plants = @mask_request.mask_request_plants.includes(:plant)
    return if mask_request_plants.empty?

    plant_names = mask_request_plants.map { |mrp| mrp.plant.english_name }.join(", ")

    begin
      details_list = fetch_bulk_plant_details(plant_names)

      details_list.each do |details|
        plant_name = details["english_name"]
        # Find matching plant (case-insensitive search might be safer, but assuming exact match for now based on LLM instruction)
        plant = Plant.find_by(english_name: plant_name)

        if plant
          # Update Plant details
          plant.update!(
            description: details["description"],
            size: details["size"],
            validated: true
          )

          # Update MaskRequestPlant quantity
          mrp = mask_request_plants.find { |m| m.plant_id == plant.id }
          if mrp
            mrp.update!(quantity: details["quantity"])
          end
        else
          Rails.logger.warn("Could not find plant matching returned name: #{plant_name}")
        end
      end
    rescue => e
      Rails.logger.error("Error in bulk plant validation: #{e.message}")
      # Fallback: could try individual validation or just leave as is
    end
  end

  def fetch_bulk_plant_details(plant_names)
    prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("image_analysis", "plant_details_quantified")
    prompt.gsub!("<<plant_names>>", plant_names)

    # Pass the overlay image to give context for quantity estimation
    response = RubyLLM.chat.with_schema(PlantDetailsListSchema).ask(prompt, with: @mask_request.overlay)
    response.content["plants_details"]["plants"]
  end

  def detect_sketch
    prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("image_analysis", "sketch_detection")
    response = RubyLLM.chat.with_schema(SketchDetectionSchema).ask(prompt, with: @mask_request.overlay)
    is_sketch = response.content["analysis"]["is_sketch"]
    @mask_request.update(sketch: is_sketch)
    is_sketch
  rescue => e
    Rails.logger.error("Sketch detection failed: #{e.message}")
    false
  end

  def generate_sketch_pipeline
    # 1. Main View: Sketch -> 3D Rendering
    @mask_request.main_view!
    generate_3d_view

    # 2. Rotated View: 3D Rendering -> Photorealistic
    @mask_request.rotating!
    generate_photorealistic_view

    # 3. Generate Overlay using the Photorealistic Image
    @mask_request.overlaying!
    @mask_request.overlay_mask

    # 4. Drone View: Photorealistic -> Designed Garden (Overlayed)
    @mask_request.drone!
    generate_drone_view_from_sketch

    @mask_request.processed!
  end

  def generate_3d_view
    prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("image_analysis", "sketch_to_3d")
    image = @mask_request.image

    payload = gcp_payload(prompt:, image:)
    response = fetch_gcp_response(payload)
    blob = save_gcp_results(response)
    @mask_request.main_view.attach(blob)
  end

  def generate_photorealistic_view
    return unless @mask_request.main_view.attached?

    prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("image_analysis", "3d_to_photorealistic")
    image = @mask_request.main_view

    payload = gcp_payload(prompt:, image:)
    response = fetch_gcp_response(payload)
    blob = save_gcp_results(response)
    @mask_request.rotated_view.attach(blob)
  end

  def generate_drone_view_from_sketch
    return unless @mask_request.rotated_view.attached?

    # Use the standard design prompt logic but apply it to the photorealistic image
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
    @mask_request.drone_view.attach(blob)
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
    if @mask_request.canva.user.afford_generation?
      @mask_request.rotating!
      rotate_view

      @mask_request.drone!
      drone_view
      @mask_request.processed!
    else
      generate_premium_locked_views
      @mask_request.complete!
    end
  rescue StandardError => e
    @mask_request.update error_msg: e.message
  end

  def generate_premium_locked_views
    @mask_request.rotating!
    create_watermarked_view(:rotated_view)

    @mask_request.drone!
    create_watermarked_view(:drone_view)
  end

  def create_watermarked_view(attachment_name)
    return unless @mask_request.main_view.attached?

    # Download main view
    main_image_blob = @mask_request.main_view.download
    main_image = MiniMagick::Image.read(main_image_blob)

    main_image.combine_options do |c|
      c.blur "0x20"
      c.gravity "Center"
      c.pointsize "100"
      c.fill "white"
      c.stroke "black"
      c.strokewidth "2"

      c.font "DejaVu-Sans"

      c.annotate "0", "Premium Only"
    end

    blob = upload_blob(main_image)
    @mask_request.send(attachment_name).attach(blob)
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
