module VideoPipeline
  class GenerateImagesService
    IMAGEN_MODEL = "imagen-4.0-fast-generate-001"

    def initialize(narration_scene)
      @narration_scene = narration_scene
    end

    def perform
      @narration_scene.image_prompts.each do |image_prompt|
        next if image_prompt.image.attached?

        generate_image(image_prompt)
      end
    end

    private

    def generate_image(image_prompt)
      payload = {
        "instances" => [
          { "prompt" => image_prompt.prompt }
        ],
        "parameters" => {
          "sampleCount" => 1,
          "outputMimeType" => "image/jpeg",
          "aspectRatio" => aspect_ratio
        }
      }

      response = fetch_gcp_response(payload)
      save_image(image_prompt, response)
    end

    def gcp_connection
      Faraday.new(
        url: "https://generativelanguage.googleapis.com/v1beta/models/#{IMAGEN_MODEL}:predict",
        headers: {
          "Content-Type" => "application/json",
          "x-goog-api-key" => ENV["GEMINI_API_KEYS"].split("__").sample
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
      rescue Faraday::BadRequestError => e
        Rails.logger.error("Bad request to Imagen API: #{e.message}")
        Rails.logger.error("Response body: #{e.response[:body]}")
        raise
      end
    end

    def save_image(image_prompt, response)
      return unless response.is_a?(Hash)

      generated_image = response.dig("predictions", 0)
      return if generated_image.blank?

      if generated_image.blank?
        Rails.logger.error("Imagen did not return an image. Response: #{response}")
        return
      end

      img_from_b64 = Base64.decode64(generated_image["bytesBase64Encoded"])

      # read from image_data
      mime_type = generated_image["mimeType"]
      extension = mime_type.split("/").last

      temp_file = Tempfile.new([ "generated_image", ".#{extension}" ], binmode: true)
      temp_file.write(img_from_b64)
      temp_file.rewind

      image_prompt.image.attach(
        io: temp_file,
        filename: "generated_image_#{image_prompt.id}.#{extension}",
        content_type: mime_type
      )
    end

    def aspect_ratio
      video_mode = @narration_scene.subchapter.chapter.video_mode

      case video_mode
      when "portrait"
        "9:16"
      when "landscape"
        "16:9"
      else
        "1:1"
      end
    end
  end
end
