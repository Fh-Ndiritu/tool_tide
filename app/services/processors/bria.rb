# frozen_string_literal: true

module Processors
  class Bria
    include ImageModifiable
    def initialize(id)
      @landscape_request = LandscapeRequest.find(id)
      @landscape = @landscape_request.landscape
    end

    def self.perform(*args)
      new(*args).process
    end

    def process
      @landscape_request.generating_landscape!
      bria_response = fetch_bria_response

      @landscape_request.saving_results!
      process_bria_results(bria_response)
      @landscape_request.processed!
    rescue StandardError => e
      raise "Bria failed with error: #{e.message}"
    end

    private

    def fetch_bria_response
      BriaAi::Client.new.gen_fill(
        image_input: encode_original_image,
        mask_input: flip_mask_colors,
        prompt: @landscape_request.full_prompt,
        sync: true,
        num_results: 3
      )
    end

    def process_bria_results(bria_response)
      unless bria_response.success? && bria_response.body["urls"].any?
        raise BriaAi::APIError,
              "Bria AI API call failed or returned no results. Response: #{bria_response.body.inspect}"
      end

      bria_response.body["urls"].each do |url|
        next unless url.is_a?(String)

        download_and_save_image(url)
      end
    end

    def download_and_save_image(modified_image_url)
      return if modified_image_url.blank?

      begin
        downloaded_image = URI.parse(modified_image_url).open
        blob = ActiveStorage::Blob.create_and_upload!(
          io: downloaded_image,
          filename: "landscaped_#{SecureRandom.hex(8)}.png",
          content_type: downloaded_image.content_type
        )
        @landscape_request.modified_images.attach(blob)

        @landscape.save!
      rescue OpenURI::HTTPError => e
        raise "Failed to download processed image: #{e.message}"
      rescue StandardError => e
        raise "Failed to attach processed image to record: #{e.message}"
      ensure
        downloaded_image.close if defined?(downloaded_image) && !downloaded_image.nil?
      end
    end

    def encode_original_image
      Base64.strict_encode64(@landscape.original_image.variant(:to_process).processed.blob.download)
    rescue ActiveStorage::FileNotFoundError => e
      raise BriaAi::Error, "Original image file not found in Active Storage: #{e.message}"
    rescue StandardError => e
      raise BriaAi::Error, "An unexpected error occurred while preparing the original image for Bria AI: #{e.message}"
    end

    # Bria expects the white and black to be inverted in the mask
    def flip_mask_colors
      blob = @landscape_request.mask.blob
      image = MiniMagick::Image.read(blob.download)
      image.colorspace("Gray").threshold("50%").negate

      image.format "png"
      inverted_base64 = Base64.strict_encode64(image.to_blob)
      "data:image/png;base64,#{inverted_base64}"
    rescue MiniMagick::Error => e
      raise "Image processing error with MiniMagick: #{e.message}. " \
            "Please ensure ImageMagick is correctly installed and accessible on your system."
    rescue StandardError => e
      raise "An unexpected error occurred during mask color flipping: #{e.message}"
    end
  end
end
