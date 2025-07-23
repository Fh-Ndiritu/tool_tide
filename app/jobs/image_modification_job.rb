# app/jobs/image_modification_job.rb
require "mini_magick"

class ImageModificationJob < ApplicationJob
  queue_as :default
  def perform(landscape_id, raw_mask_image_data)
    Rails.logger.info "Starting ImageModificationJob for Landscape ID: #{landscape_id}"
    @landscape = Landscape.find(landscape_id)
    save_mask(raw_mask_image_data) if raw_mask_image_data.present?
    @b64_input_image =  prepare_original_image_for_bria(@landscape.original_image)

    @premium = false
    @b64_mask_image = flip_mask_colors
    if @premium
      gcp_inpaint
    else
      bria_inpaint
    end

    if @landscape.modified_image.attached?
      original_image_url = @landscape.original_image.variant(:final).processed.url
      ActionCable.server.broadcast(
        "landscape_channel",
        { original_image_url:, modified_image_url: @landscape.modified_image.url }
      )
    end
  end


  private


  def gcp_inpaint
    # response = fetch_imagen3_response
    response = fetch_imagen2_response
    if response.is_a?(Hash) && response["predictions"].present?
      save_b64_results(response["predictions"][0])
    else
      Rails.logger.error "Unexpected response from GCP: #{response}"
      raise "Unexpected response from GCP"
    end
  end

  def fetch_imagen3_response
    location = ENV.fetch("GCP_LOCATION")
    endpoint = "https://#{location}-aiplatform.googleapis.com/v1/projects/#{ ENV.fetch("GCP_PROJECT_ID")}/locations/#{location}/publishers/google/models/imagen-3.0-capability-001:predict"
    Gcp::Client.new.send(endpoint, gcp_payload)
  end

  def fetch_imagen2_response
    location = ENV.fetch("GCP_LOCATION")
    endpoint = "https://#{location}-aiplatform.googleapis.com/v1/projects/#{ ENV.fetch("GCP_PROJECT_ID")}/locations/#{location}/publishers/google/models/imagegeneration@006:predict"
    Gcp::Client.new.send(endpoint, gcp2_payload)
  end

  def bria_inpaint
    bria_response = BriaAi::Client.new.gen_fill(
      image_input: @b64_input_image,
      mask_input:  @b64_mask_image,
      prompt: @landscape.prompt,
      sync: true,
      num_results: 1
    )
    process_bria_results(bria_response)
  rescue StandardError => e
    Rails.logger.error "Image modification job failed for Landscape ID #{landscape_id}: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
    ActionCable.server.broadcast(
      "landscape_channel",
      { error: "An unexpected error occurred during image modification: #{e.message}" }
    )
  end

  def save_b64_results(b64_result)
    # gcp will responnd with a hash of type and data
    img_from_b64 = Base64.decode64(b64_result["bytesBase64Encoded"])
    extension = b64_result["mimeType"].split("/").last
    temp_path = Rails.root.join("tmp", "#{SecureRandom.hex(10)}.#{extension}")
    File.open(temp_path, "wb") do |file|
      file.write(img_from_b64)
    end
    @landscape.modified_image.attach(io: File.open(temp_path), filename: "modified_image.#{extension}")
  ensure
    File.delete(temp_path) if File.exist?(temp_path)
  end

  def process_bria_results(bria_response)
    if bria_response.success? && bria_response.body["urls"].any?
      first_result = bria_response.body["urls"].first

      if first_result.is_a?(String)
          modified_image_url = first_result
          download_and_save_image(modified_image_url)
      else
        raise BriaAi::APIError, "Bria AI response did not contain expected image output in 'urls' array."
      end
    else
      raise BriaAi::APIError, "Bria AI API call failed or returned no results. Response: #{bria_response.body.inspect}"
    end
  end

  def download_and_save_image(modified_image_url)
    return unless modified_image_url.present?

    begin
      downloaded_image = URI.parse(modified_image_url).open
      @landscape.modified_image.attach(
        io: downloaded_image,
        filename: "landscaped_#{SecureRandom.hex(8)}.png",
        content_type: downloaded_image.content_type # Infer content type
      )

      @landscape.save!
    rescue OpenURI::HTTPError => e
      raise "Failed to download processed image: #{e.message}"
    rescue => e
      raise "Failed to attach processed image to record: #{e.message}"
    ensure
      downloaded_image.close if defined?(downloaded_image)
    end
  end

  def save_mask(raw_mask_image_data)
    # Extract base64 content and decode
    _mime_type, base64_content = raw_mask_image_data.split(",", 2)
    decoded_mask = Base64.decode64(base64_content)

    # Create a Tempfile for the mask
    mask_temp_file = Tempfile.new([ "mask_data_", ".png" ], binmode: true)
    mask_temp_file.write(decoded_mask)
    mask_temp_file.rewind

    # Attach the mask to the landscape record
    @landscape.mask_image_data.attach(
      io: mask_temp_file,
      filename: "mask_#{SecureRandom.hex(8)}.png",
      content_type: "image/png"
    )
    Rails.logger.info "Mask image data saved to Active Storage for Landscape ID: #{@landscape.id}"
  rescue => e
    Rails.logger.error "Failed to save mask_image_data for Landscape ID #{@landscape.id}: #{e.message}"
    # For now, we'll log and continue, as the AI processing might still work even if mask saving fails.
  ensure
    mask_temp_file.close if mask_temp_file
    mask_temp_file.unlink if mask_temp_file
  end


  def gcp2_payload
    {
      "instances": [
        {
          "prompt": "A beautiful garden of red roses, tulips, and daisies with a green lawm and a fountain in the center",
           "image": {
            "bytesBase64Encoded": @b64_input_image
           },
           "mask": {
              "image": {
                "bytesBase64Encoded": @b64_mask_image.split(",", 2).last
              }
           }
        }
      ],
      "parameters": {
        "editConfig": {
          "editMode": "inpainting-insert",
          guidanceScale: 450
        },
        "sampleCount": 1
      }
    }
  end


  def gcp_payload
    {
      "instances": [
        {
          "prompt": "Bright red roses in the garden",
          "referenceImages": [
            {
              "referenceType": "REFERENCE_TYPE_RAW",
              "referenceId": 1,
              "referenceImage": {
                "bytesBase64Encoded": @b64_input_image
              }
            },
            {
              "referenceType": "REFERENCE_TYPE_MASK",
              "referenceId": 2,
              "referenceImage": {
                "bytesBase64Encoded":  @b64_mask_image.split(",", 2).last
              },
              "maskImageConfig": {
                "maskMode": "MASK_MODE_USER_PROVIDED"
              }
            }
          ]
        }
      ],
      "parameters": {
        "editConfig": {
          "baseSteps": 35
        },
        "editMode": "EDIT_MODE_INPAINT_INSERTION",
        "sampleCount": 1
      }
    }
  end

  # This helper method now ALWAYS reads the Active Storage blob and returns its Base64 encoding.
  # This makes it independent of whether Active Storage generates public, private, or localhost URLs.
  def prepare_original_image_for_bria(original_image_attachment)
    unless original_image_attachment.attached?
      raise BriaAi::Error, "Original image is not attached to the landscape record."
    end

    Rails.logger.info "Reading original image from Active Storage blob and encoding to Base64."
    encoded_image_data = Base64.strict_encode64(original_image_attachment.variant(:final).processed.download)
    Rails.logger.info "Successfully encoded Active Storage image to Base64."
    encoded_image_data
  rescue ActiveStorage::FileNotFoundError => e
    Rails.logger.error "Active Storage file not found for landscape ID #{@landscape.id}: #{e.message}"
    raise BriaAi::Error, "Original image file not found in Active Storage: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Unexpected error encoding original image to Base64 for Bria AI: #{e.class}: #{e.message}"
    raise BriaAi::Error, "An unexpected error occurred while preparing the original image for Bria AI: #{e.message}"
  end


  # GCP and Bria expect the white and black to be inverted in the mask
  def flip_mask_colors
    blob = @landscape.mask_image_data.variant(:final).processed.blob
    begin
      image = MiniMagick::Image.read(blob.download)
      image.negate
      inverted_image_binary_data = image.to_blob
      inverted_base64 = Base64.encode64(inverted_image_binary_data)
      "data:image/png;base64,#{inverted_base64}"
    rescue MiniMagick::Error => e
      raise "Image processing error with MiniMagick: #{e.message}. " \
            "Please ensure ImageMagick is correctly installed and accessible on your system."
    rescue => e
      raise "An unexpected error occurred during mask color flipping: #{e.message}"
    end
  end
end
