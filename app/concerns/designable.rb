module Designable
  extend ActiveSupport::Concern

  def upload_blob(masked_image, mime_type = "png")
    io_object = StringIO.new(masked_image.to_blob)

    ActiveStorage::Blob.create_and_upload!(
      io: io_object,
      filename: "full_blend.png",
      content_type: "image/#{mime_type}"
    )
  end

  def gcp_connection
    Faraday.new(
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent",
      headers: {
        "Content-Type" => "application/json",
        "x-goog-api-key" => ENV["GEMINI_API_KEYS"].split("____").sample
      }
    ) do |f|
      f.response :raise_error
      # Time to wait for the connection to open
      f.options.open_timeout = 30
      # Total time for the request to complete
      f.options.timeout = 120
      # Time to wait for a read to complete
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


  def gcp_payload(prompt:, image:)
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
    }
  end

  # rotated_landscape_prompt and aerial_landscape_prompt removed as we now generate 3 variations of the same prompt.

  def save_gcp_results(response)
    return unless response.is_a?(Hash)

    data = response.dig("candidates", 0, "content", "parts").try(:last)

    return if data.blank?

    image = data["inlineData"]

    return if image.blank? || image["data"].blank?

    img_from_b64 = Base64.decode64(image["data"])
    extension = image["mimeType"].split("/").last

    temp_file = Tempfile.new([ "modified_image", ".#{extension}" ], binmode: true)
    temp_file.write(img_from_b64)
    temp_file.rewind

    ActiveStorage::Blob.create_and_upload!(
      io: temp_file,
      filename: "modified_image.#{extension}",
      content_type: image["mimeType"]
    )
  end

  def charge_generation
    @mask_request.reload
    image_count = [ @mask_request.main_view.attached?, @mask_request.rotated_view.attached?, @mask_request.drone_view.attached? ].count(true)

    if image_count.zero?
      @mask_request.update progress: :failed, error_msg: "Image generation failed.", user_error: "Image generation failed. Please try again."
      return
    end

    cost = GOOGLE_IMAGE_COST * image_count

    if cost.zero?
      @mask_request.update progress: :failed, error_msg: "You have no credits left."
    else
      @mask_request.canva.user.charge_pro_cost!(cost)
      @mask_request.complete!
    end

  end
end
