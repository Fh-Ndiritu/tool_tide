module Admin::LandscapesHelper
   def location(ip_address)
    # Ensure Geocoder gem is installed and configured
    # gem 'geocoder'
    # config/initializers/geocoder.rb with your API key if needed
    result = Geocoder.search(ip_address).first

    if result
      "#{result&.city}, #{result&.country}"
    else
     nil
    end
  end
end
