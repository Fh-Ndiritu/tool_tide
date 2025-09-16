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

def fetch_gcp_response(payload, max_retries = 3)
  retries = 0
  begin
    response = @connection.post("") do |req|
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

  def rotated_landscape_prompt
    "Given this 8k highly detailed image of a landscaped garden compound, move the camera 120% horizontally to view the garden from a different angle.
   Focus on shifting the camera to focus on the garden with a high resolution and professional looking angle."
  end

  def aerial_landscape_prompt
    "Given this image design of a well landscaped garden compound, change the perspective an aerial drone view to show the garden landscaping from above.
  Focus on the details of the garden and show the house in the periphery from above. Make it an aerial view from a DJI drone perspective."
  end

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
    @mask_request.canva.user.charge_pro_cost!(GOOGLE_IMAGE_COST * image_count)
    @mask_request.complete!
  end
end
