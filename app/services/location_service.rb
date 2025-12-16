require 'net/http'
require 'json'

class LocationService
  LocationResult = Struct.new(:ip, :city, :region_name, :country_name, :country_code, :latitude, :longitude, :zip_code, :time_zone, keyword_init: true) do
    def country
      country_name
    end

    def state
      region_name
    end

    def state_code
      # FreeIPAPI doesn't provide state code directly, usually
      nil
    end

    def address
      [city, region_name, country_name].compact.join(', ')
    end
  end

  def self.lookup(ip)
    return nil if ip.blank? || ip == '127.0.0.1' || ip == '::1'

    begin
      uri = URI("https://free.freeipapi.com/api/json/#{ip}")
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        return nil unless data['ipVersion'].present? # Check if we got a valid IP response

        LocationResult.new(
          ip: data['ipAddress'],
          city: data['cityName'],
          region_name: data['regionName'],
          country_name: data['countryName'],
          country_code: data['countryCode'],
          latitude: data['latitude']&.to_f,
          longitude: data['longitude']&.to_f,
          zip_code: data['zipCode'],
          time_zone: data['timeZone']
        )
      else
        Rails.logger.error("LocationService Error: #{response.code} - #{response.message}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("LocationService Exception: #{e.message}")
      nil
    end
  end
end
