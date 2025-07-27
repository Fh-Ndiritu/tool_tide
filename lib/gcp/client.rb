# frozen_string_literal: true

module Gcp
  class Client
    def send(endpoint, payload)
        access_token = generate_access_token

        response = Faraday.post(endpoint) do |req|
          req.headers["Content-Type"] = "application/json"
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.body = payload.to_json
        end

        raise "Faraday Error: #{response.status} - #{response.body}" unless response.success?

        JSON.parse(response.body)
    end

    private

    def generate_access_token
      credentials = Google::Auth::ServiceAccountCredentials.make_creds(
        scope: "https://www.googleapis.com/auth/cloud-platform"
      )

      access_token = credentials.fetch_access_token!["access_token"]

      raise "Error: Unable to generate access token" if access_token.blank?

      access_token
    end
  end
end
