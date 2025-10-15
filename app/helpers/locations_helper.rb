module LocationsHelper
  def generate_location_seo_paragraph(location)
    # 1. Extract and sanitize core attributes
    city_name = location.name
    country = location.country_code
    admin_name = location.admin_name.presence
    is_capital = (location.capital == "primary")
    population_val = location.population.to_i

    # 2. Determine population context phrase
    if population_val > 1000000
      population_text = "This bustling metropolitan area"
    elsif population_val > 100000
      population_text = "This vibrant regional center"
    else
      population_text = "This distinctive locale"
    end

    # 3. Construct the base sentence based on location status
    if is_capital
      base_sentence = "#{city_name} is the primary capital of #{admin_name}, #{country}, making it a focal point for culture and design. #{population_text} is a thriving hub."
    elsif admin_name
      base_sentence = "#{city_name}, located in the beautiful #{admin_name} region of #{country}, offers a unique blend of local charm and architectural diversity. #{population_text} is a great source for design inspiration."
    else
      # Fallback for less detailed records
      base_sentence = "#{city_name} is a key location within #{country}. #{population_text} provides countless settings perfect for stunning landscaping transformations."
    end

    # 4. Assemble the final SEO paragraph
    "#{base_sentence} Explore our collection of user-submitted, AI-generated landscaping designs, gardens, and outdoor living ideas tailored specifically for properties in and around #{city_name}. Get inspired for your next project today!"
  end
end
