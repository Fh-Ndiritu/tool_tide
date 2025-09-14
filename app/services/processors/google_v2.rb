# frozen_string_literal: true

module Processors
  class GoogleV2
    include ImageModifiable

    def initialize(id)
      @landscape_request = LandscapeRequest.find(id)
      @landscape = @landscape_request.landscape
    end

    def self.perform(*args)
      new(*args).process
    end

    def process
      # we expect mask validations to be done ealier
      apply_mask_for_transparency

      raise "Image blend not found" unless @landscape_request.reload.full_blend.attached?

      @landscape_request.generating_landscape!
      try_google_request(:generate_initial_landscape)

      @landscape_request.changing_angles!
      try_google_request(:generate_rotated_landscape)

      # @landscape_request.generating_drone_view!
      # try_google_request(:generate_aerial_landscape)
      @landscape_request.processed!
    rescue StandardError => e
      raise "Google Processor failed with: #{e.message}"
    end

    private

    def try_google_request(method)
      max_retries = 3
      retries = 0

      begin
        save_response(send(method))
      rescue StandardError => e
        Rails.logger.info("GCP failed #{method} with: #{e.message}")
        retries += 1
        raise "Max retries reached for #{method}" if retries > max_retries

        save_response(send(method))
      end
    end

    def save_response(response)
      raise "Response is not a Hash" unless response.is_a?(Hash)

      data = response.dig("candidates", 0, "content", "parts", 1, "inlineData")

      raise "Image is missing in API response" unless data.present?

      save_b64_results(data)
    end


    def fetch_gcp_response(payload)
      begin
        response = conn.post do |req|
          req.body = payload
        end

        # Check if the HTTP request was successful (status code 200).
        unless response.status == 200
          Rails.logger.error "GCP request failed with status #{response.status}: #{response.body}"
          raise "API call failed with status #{response.status}"
        end

        JSON.parse(response.body)
      rescue Faraday::Error => e
                    binding.irb
        Rails.logger.error "Faraday connection error: #{e.message}"
        raise "Failed to connect to GCP API: #{e.message}"
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse JSON response: #{e.message}"
        raise "Invalid response from GCP API: #{e.message}"
      end
    end

    def generate_initial_landscape
      payload = gcp_payload(initial_landscape_prompt, @landscape_request.full_blend)
      fetch_gcp_response(payload)
    end

    def generate_rotated_landscape
      payload = gcp_payload(rotated_landscape_prompt, @landscape_request.modified_images.last)
      fetch_gcp_response(payload)
    end

    def generate_aerial_landscape
      payload = gcp_payload(aerial_landscape_prompt, @landscape_request.modified_images.first)
      fetch_gcp_response(payload)
    end

    def gcp_payload(prompt, image)
      {
        "contents" => [
          {
            "parts" => [
              {
                "text" => prompt

              },
              {
                "inline_data" => {
                  "mime_type" => image.blob.content_type,
                  "data" => Base64.strict_encode64(image.blob.download)
                }
              }
            ]
          }
        ]
      }.to_json
    end

    def conn
      endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image-preview:generateContent"

      @conn ||= Faraday.new(
        url: endpoint,
        headers: {
          "Content-Type" => "application/json",
          "x-goog-api-key" => ENV["GEMINI_API_KEY"]
        }
      ) do |f|
        # Time to wait for the connection to open
        f.options.open_timeout = 30
        # Total time for the request to complete
        f.options.timeout = 120
        # Time to wait for a read to complete
        f.options.read_timeout = 120
      end
    end
  end
end
