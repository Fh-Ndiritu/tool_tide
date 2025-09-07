# frozen_string_literal: true

module Admin
  module LandscapesHelper
    def location_ip(ip_address)
      # Ensure Geocoder gem is installed and configured
      # gem 'geocoder'
      # config/initializers/geocoder.rb with your API key if needed
      result = Geocoder.search(ip_address).first
      return unless result&.country

      "#{result&.city}, #{result&.country}"
    end
  end
end
