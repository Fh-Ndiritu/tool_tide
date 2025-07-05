# app/jobs/image_modification_job.rb
# This job processes an image by applying Bria AI's inpainting capabilities.

require "base64"
require "tempfile" # For handling temporary files if Base64 image is returned
require "securerandom" # For generating unique filenames
require "open-uri" # For opening URLs, including potentially Active Storage public URLs
require 'mini_magick' # Ensure MiniMagick is required if flip_mask_colors uses it

class ImageModificationJob < ApplicationJob
  queue_as :default # Or a specific queue for AI tasks, e.g., :ai_processing

  # The perform method is where the job's main logic resides.
  # @param landscape_id [Integer] The ID of the Landscape record.
  # @param raw_mask_image_data [String] The Base64-encoded mask image (e.g., "data:image/png;base64,...").
  def perform(landscape_id, raw_mask_image_data)
    Rails.logger.info "Starting ImageModificationJob for Landscape ID: #{landscape_id}"
    @landscape = Landscape.find(landscape_id)

    # --- SAVE MASK_IMAGE_DATA TO ACTIVE STORAGE ---
    if raw_mask_image_data.present?
      begin
        # Extract base64 content and decode
        _mime_type, base64_content = raw_mask_image_data.split(",", 2)
        decoded_mask = Base64.decode64(base64_content)

        # Create a Tempfile for the mask
        mask_temp_file = Tempfile.new(["mask_data_", ".png"], binmode: true)
        mask_temp_file.write(decoded_mask)
        mask_temp_file.rewind

        # Attach the mask to the landscape record
        @landscape.mask_image_data.attach(
          io: mask_temp_file,
          filename: "mask_#{SecureRandom.hex(8)}.png",
          content_type: "image/png"
        )
        Rails.logger.info "Mask image data saved to Active Storage for Landscape ID: #{landscape_id}"
      rescue => e
        Rails.logger.error "Failed to save mask_image_data for Landscape ID #{landscape_id}: #{e.message}"
        # For now, we'll log and continue, as the AI processing might still work even if mask saving fails.
      ensure
        mask_temp_file.close if mask_temp_file
        mask_temp_file.unlink if mask_temp_file
      end
    end
    # --- END SAVE MASK_IMAGE_DATA ---


    # Initialize the Bria AI client.
    bria_client = BriaAi::Client.new
    begin
      # Always encode the original image to Base64 for Bria AI
      image_input_for_bria = prepare_original_image_for_bria(@landscape.original_image)
      prompt = @landscape.prompt # Moved here as it's used in the Bria AI call info

      Rails.logger.info "Calling Bria AI /image-editing/gen_fill endpoint with image (Base64), prompt: '#{prompt}'"

      # Flip mask colors before sending to Bria AI if their API expects it
      mask_input_for_bria = flip_mask_colors(raw_mask_image_data)

      bria_response = bria_client.gen_fill(
        image_input: image_input_for_bria, # This is now always Base64
        mask_input: mask_input_for_bria,    # This is also Base64
        prompt: prompt,
        sync: true,
        num_results: 1
      )

      modified_image_url = nil

      if bria_response.success? && bria_response.body && bria_response.body["urls"] && bria_response.body["urls"].any?
        first_result = bria_response.body["urls"].first

        if first_result.is_a?(Hash) && first_result["url"]
          Rails.logger.info "Bria AI returned image URL: #{first_result['url']}"
          modified_image_url = first_result["url"]
        elsif first_result.is_a?(Hash) && first_result["b64_json"]
          Rails.logger.info "Bria AI returned Base64 image directly."
          # Store the Base64 data directly; we'll attach it in the next step
          modified_image_data_b64 = first_result["b64_json"]
          # We'll use a placeholder data URL to indicate it's Base64 for the attachment logic
          modified_image_url = "data:image/png;base64,#{modified_image_data_b64}"
        elsif first_result.is_a?(String) # Handle case where 'urls' directly contains string URLs
            Rails.logger.info "Bria AI returned direct image URL: #{first_result}"
            modified_image_url = first_result
        else
          raise BriaAi::APIError, "Bria AI response did not contain expected image output (url or b64_json) in 'urls' array."
        end
      else
        Rails.logger.error "Bria AI response was unsuccessful or empty: #{bria_response.body.inspect}"
        raise BriaAi::APIError, "Bria AI API call failed or returned no results. Response: #{bria_response.body.inspect}"
      end

      # --- SAVE LANDSCAPED_IMAGE TO ACTIVE STORAGE ---
      if modified_image_url.present?
        begin
          if modified_image_url.start_with?("data:image/")
            # If it's a data URL (e.g., from Bria's b64_json), decode and attach
            _mime_type, base64_content = modified_image_url.split(",", 2)
            decoded_image = Base64.decode64(base64_content)
            landscaped_temp_file = Tempfile.new(["landscaped_", ".png"], binmode: true)
            landscaped_temp_file.write(decoded_image)
            landscaped_temp_file.rewind

            @landscape.landscaped_image.attach(
              io: landscaped_temp_file,
              filename: "landscaped_#{SecureRandom.hex(8)}.png",
              content_type: "image/png" # Assuming PNG from Bria AI output
            )
          else
            # If it's a remote URL, open it and attach
            downloaded_image = URI.parse(modified_image_url).open
            @landscape.landscaped_image.attach(
              io: downloaded_image,
              filename: "landscaped_#{SecureRandom.hex(8)}.png",
              content_type: downloaded_image.content_type # Infer content type
            )
          end

          @landscape.save! # Save the landscape record to persist attachments
          modified_image_url = @landscape.landscaped_image.url # Update URL to Active Storage public URL
          Rails.logger.info "Landscaped image saved to Active Storage and updated URL for Landscape ID: #{landscape_id}"
        rescue OpenURI::HTTPError => e
          Rails.logger.error "Failed to download modified image from Bria AI URL #{modified_image_url}: #{e.message}"
          raise "Failed to download processed image: #{e.message}"
        rescue => e
          Rails.logger.error "Failed to save landscaped_image for Landscape ID #{landscape_id}: #{e.message}"
          raise "Failed to attach processed image to record: #{e.message}"
        ensure
          landscaped_temp_file.close if defined?(landscaped_temp_file) && landscaped_temp_file
          landscaped_temp_file.unlink if defined?(landscaped_temp_file) && landscaped_temp_file
          downloaded_image.close if defined?(downloaded_image) && downloaded_image # Close URI.open stream
        end
      end
      # --- END SAVE LANDSCAPED_IMAGE ---

      # 3. Broadcast the result back to the frontend via Action Cable.
      final_original_image_url = @landscape.original_image.url # Get the public URL of the original image
      ActionCable.server.broadcast(
        "landscape_channel",
        { original_image_url: final_original_image_url, modified_image_url: modified_image_url }
      )
      Rails.logger.info "Image modification job completed for Landscape ID #{landscape_id}. Result broadcasted: #{modified_image_url}"

    # --- Error Handling (remaining unchanged) ---
    rescue BriaAi::AuthenticationError => e
      Rails.logger.error "Bria AI Authentication Error for Landscape ID #{landscape_id}: #{e.message}"
      ActionCable.server.broadcast(
        "landscape_channel",
        { error: "Authentication failed with Bria AI. Please check your API token." }
      )
    rescue BriaAi::RateLimitError => e
      Rails.logger.warn "Bria AI Rate Limit Exceeded for Landscape ID #{landscape_id}: #{e.message}"
      ActionCable.server.broadcast(
        "landscape_channel",
        error: "Bria AI rate limit exceeded. Please try again shortly."
      )
    rescue BriaAi::APIError => e
      Rails.logger.error "Bria AI API Error for Landscape ID #{landscape_id}: #{e.message}"
      ActionCable.server.broadcast(
        "landscape_channel",
       { error: "Failed to process image with Bria AI: #{e.message}" }
      )
    rescue BriaAi::Error => e
      Rails.logger.error "General Bria AI error for Landscape ID #{landscape_id}: #{e.message}"
      ActionCable.server.broadcast(
        "landscape_channel",
        { error: "An unexpected Bria AI service error occurred: #{e.message}" }
      )
    rescue StandardError => e
      Rails.logger.error "Image modification job failed for Landscape ID #{landscape_id}: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
      ActionCable.server.broadcast(
        "landscape_channel",
        { error: "An unexpected error occurred during image modification: #{e.message}" }
      )
    end
  end

  private

  # This helper method now ALWAYS reads the Active Storage blob and returns its Base64 encoding.
  # This makes it independent of whether Active Storage generates public, private, or localhost URLs.
  # @param original_image_attachment [ActiveStorage::Attached::One] The Active Storage attachment object.
  # @return [String] A Base64 encoded string of the image (without the "data:image/..." prefix).
  def prepare_original_image_for_bria(original_image_attachment)
    unless original_image_attachment.attached?
      raise BriaAi::Error, "Original image is not attached to the landscape record."
    end

    Rails.logger.info "Reading original image from Active Storage blob and encoding to Base64."
    # `original_image_attachment.download` reads the content directly from storage.
    encoded_image_data = Base64.strict_encode64(original_image_attachment.download)
    Rails.logger.info "Successfully encoded Active Storage image to Base64."
    encoded_image_data
  rescue ActiveStorage::FileNotFoundError => e
    Rails.logger.error "Active Storage file not found for landscape ID #{@landscape.id}: #{e.message}"
    raise BriaAi::Error, "Original image file not found in Active Storage: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Unexpected error encoding original image to Base64 for Bria AI: #{e.class}: #{e.message}"
    raise BriaAi::Error, "An unexpected error occurred while preparing the original image for Bria AI: #{e.message}"
  end


  def flip_mask_colors(data_url)
    unless data_url.start_with?("data:image/png;base64,")
      raise ArgumentError, "Invalid data_url format. Expected 'data:image/png;base64,' prefix."
    end

    _mime_type, base64_data = data_url.split(",", 2)

    if base64_data.nil?
      raise ArgumentError, "Could not extract base64 data from the provided URL."
    end

    decoded_image_data = Base64.decode64(base64_data)

    begin
      image = MiniMagick::Image.read(decoded_image_data)
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
