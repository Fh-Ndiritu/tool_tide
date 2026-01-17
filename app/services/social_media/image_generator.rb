module SocialMedia
  class ImageGenerator
    def self.perform(prompt)
      new.generate(prompt)
    end

    def generate(prompt)
      payload = gcp_payload(prompt: prompt)
      response = fetch_gcp_response(payload)
      save_gcp_results(response)
    end

    private

    def gcp_connection
      Faraday.new(
        url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent",
        headers: {
          "Content-Type" => "application/json",
          "x-goog-api-key" => ENV["GEMINI_API_KEYS"].split("____").sample
        }
      ) do |f|
        f.response :raise_error
        f.options.open_timeout = 30
        f.options.timeout = 120
        f.options.read_timeout = 120
      end
    end

    def fetch_gcp_response(payload, max_retries = 3)
      retries = 0
      begin
        response = gcp_connection.post("") do |req|
          req.body = payload.to_json
        end
        JSON.parse(response.body)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        Rails.logger.warn("Request failed: #{e.message}. Retrying... (#{retries + 1}/#{max_retries})")
        retries += 1
        retry if retries < max_retries
        raise
      end
    end

    def gcp_payload(prompt:)
      # Adapted to be Text-to-Image (no inline_data image)
      {
        "contents" => [
          {
            "parts" => [
              { "text" => prompt }
            ]
          }
        ]
      }
    end

    def save_gcp_results(response)
      return unless response.is_a?(Hash)

      data = response.dig("candidates", 0, "content", "parts").try(:last)
      return if data.blank?

      image = data["inlineData"]
      # Gemini API might return different format for Text-to-Image vs Image-to-Image??
      # Usually it returns inlineData with mime_type and data (base64)

      return if image.blank? || image["data"].blank?

      img_from_b64 = Base64.decode64(image["data"])
      extension = image["mimeType"].split("/").last

      # We return a temporary file object or blob that can be attached
      temp_file = Tempfile.new([ "social_image", ".#{extension}" ], binmode: true)
      temp_file.write(img_from_b64)
      temp_file.rewind

      temp_file
    end
  end
end
