# app/jobs/image_modification_job.rb
require "mini_magick"

class ImageModificationJob < ApplicationJob
  queue_as :default
  def perform(landscape_id)
    Rails.logger.info "Starting ImageModificationJob for Landscape ID: #{landscape_id}"
    @landscape = Landscape.find(landscape_id)
    @b64_input_image =  prepare_original_image_for_bria(@landscape.original_image)

    @premium = true
    @b64_mask_image = flip_mask_colors

    if @premium
      gcp_inpaint
    else
      bria_inpaint
    end

    if @landscape.modified_images.attached?
      ActionCable.server.broadcast(
        "landscape_channel",
        { status: "completed", landscape_id: @landscape.id }
      )
    end
  end


  private

  def gcp_inpaint
    # @landscape.modified_images.purge
    response = fetch_gcp_response
    if response.is_a?(Hash) && response["predictions"].present?
      save_b64_results(response["predictions"])
    else
      Rails.logger.error "Unexpected response from GCP: #{response}"
      raise "Unexpected response from GCP"
    end
  end

  def fetch_gcp_response
    location = ENV.fetch("GCP_LOCATION")
    endpoint = "https://#{location}-aiplatform.googleapis.com/v1/projects/#{ ENV.fetch("GCP_PROJECT_ID")}/locations/#{location}/publishers/google/models/imagen-3.0-capability-001:predict"
    apply_mask_for_transparency
    # Gcp::Client.new.send(endpoint, gcp_payload)
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

  def save_b64_results(predictions)
    # gcp will responnd with a hash of type and data
    predictions.each do |prediction|
      b64_data = prediction["bytesBase64Encoded"]
      img_from_b64 = Base64.decode64(b64_data)
      extension = prediction["mimeType"].split("/").last
      temp_path = Rails.root.join("tmp", "#{SecureRandom.hex(10)}.#{extension}")

      File.open(temp_path, "wb") do |file|
        file.write(img_from_b64)
      end
      @landscape.modified_images.attach(io: File.open(temp_path), filename: "modified_image.#{extension}")
      File.delete(temp_path) if File.exist?(temp_path)
    end
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

  # frozen_string_literal: true

  def apply_mask_for_transparency
    output_path = Rails.root.join("tmp", "test3.png")

    unless defined?(@landscape) && @landscape.respond_to?(:original_image) && @landscape.respond_to?(:mask_image_data)
      raise ArgumentError, "Instance variable @landscape must be set and have original_image and mask_image_data attachments."
    end

    begin
      original_image_data = @landscape.original_image.variant(:final).processed.download
      original_image = MiniMagick::Image.read(original_image_data)

      mask_image_data_binary = @landscape.mask_image_data.variant(:final).processed.download
      mask_image = MiniMagick::Image.read(mask_image_data_binary)

      unless original_image.dimensions == mask_image.dimensions
        mask_image.resize "#{original_image.width}x#{original_image.height}!"
      end

      mask_image.combine_options do |c|
        c.colorspace("Gray")
        c.threshold("50%")
      end

      mask_image.transparent("white")

      masked_image = original_image.composite(mask_image) do |c|
        c.compose "Over"
      end

      if output_path.present?
        masked_image.write(output_path)
      end

      Base64.encode64(masked_image.to_blob)

    rescue MiniMagick::Error => e
      puts "MiniMagick Error during mask application: #{e.message}"
      puts "Command attempted: #{e.command}" if e.respond_to?(:command)
      raise
    rescue StandardError => e
      puts "An unexpected error occurred during mask application: #{e.message}"
      puts e.backtrace.join("\n")
      raise
    end
  end



  def gcp_payload
     #
     {
      "instances": [
        {
          "prompt": @landscape.prompt,
          "referenceImages": [
            {
              "referenceType": "REFERENCE_TYPE_RAW",
              "referenceId": 1,
              "referenceImage": {
                "bytesBase64Encoded": apply_mask_for_transparency
              }
            }
          ]
        }
      ],
      "parameters": {
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
    blob = @landscape.mask_image_data.blob
    begin
      # image = MiniMagick::Image.read(blob)
      image = MiniMagick::Image.read(blob.download)
      image.colorspace("Gray").threshold("50%").negate

      image.format "png"
      inverted_base64 = Base64.encode64(image.to_blob)
      "data:image/png;base64,#{inverted_base64}"
    rescue MiniMagick::Error => e
      raise "Image processing error with MiniMagick: #{e.message}. " \
            "Please ensure ImageMagick is correctly installed and accessible on your system."
    rescue => e
      raise "An unexpected error occurred during mask color flipping: #{e.message}"
    end
  end
end
