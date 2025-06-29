# app/jobs/image_modification_job.rb
# This job processes an image by applying Bria AI's inpainting capabilities.

require "base64"
require "tempfile" # For handling temporary files if Base64 image is returned
require "securerandom" # For generating unique filenames
require "open-uri" # For opening URLs, including potentially Active Storage public URLs

# Ensure the BriaAI module from lib/bria_ai.rb is loaded.
# In a Rails application, `lib` is typically autoloaded, but you might need to
# add `require 'bria_ai'` if not using standard Rails autoloading or if it's
# a standalone script.
# Example for Rails initializer (`config/initializers/bria_ai.rb`):
# BriaAI.configure do |config|
#   config.api_token = ENV['BRIA_AI_API_TOKEN']
#   config.logger = Rails.logger
#   config.default_sync_mode = true # Set to true if you want immediate (blocking) results
# end

class ImageModificationJob < ApplicationJob
  queue_as :default # Or a specific queue for AI tasks, e.g., :ai_processing

  # The perform method is where the job's main logic resides.
  # @param original_image_url [String] The public URL of the original image, or an Active Storage direct upload URL.
  # @param mask_image_data [String] The Base64-encoded mask image (e.g., "data:image/png;base64,...").
  # @param prompt [String] The textual prompt to guide the inpainting process.
  def perform(original_image_url, mask_image_data, prompt)
    Rails.logger.info "Starting ImageModificationJob for #{original_image_url}"

    # Initialize the Bria AI client.
    # It will pick up configuration from `BriaAI.configure` or environment variables.
    bria_client = BriaAI::Client.new

    begin
      # Determine the actual image input for Bria AI.
      # If original_image_url is an Active Storage local path, read and encode it.
      # Otherwise, assume it's a public URL already.
      image_input_for_bria = prepare_original_image_for_bria(original_image_url)

      # 1. Call the Bria AI API for inpainting using the /gen-fill endpoint.
      #    NOTE: If you encounter a 404 error ("Resource Not Found") for the /gen-fill endpoint,
      #    please ensure that in `lib/bria_ai.rb`, the `gen_fill` method in `BriaAI::Client`
      #    is calling the correct API path: `@connection.post('image-editing/gen_fill', payload)`
      #    (using an underscore `_` instead of a hyphen `-`).
      Rails.logger.info "Calling Bria AI /image-editing/gen_fill endpoint with image: #{original_image_url}, prompt: '#{prompt}'"

      # `sync: true` requests synchronous processing. This means the API will block
      # and return the final result directly in the response, simplifying job logic.
      # If `sync: false` were used (Bria AI's default for optimal performance),
      # the response would contain a job ID, requiring a polling mechanism
      # (e.g., a separate job or a loop) to fetch the final result once ready.
      mask_input = flip_mask_colors(mask_image_data)
      bria_response = bria_client.gen_fill(
        image_input: image_input_for_bria, # Use the processed image input
        mask_input:, # The client handles removing the "data:image/png;base64," prefix.
        prompt: prompt,
        sync: true, # Request synchronous processing for immediate result.
        num_results: 1 # Request only one modified image.
      )

      # 2. Process the Bria AI response.
      #    The API generally returns the processed image in the same format as the input.
      modified_image_url = nil

      if bria_response.success? && bria_response.body && bria_response.body["urls"] && bria_response.body["urls"].any?
        first_result = bria_response.body["urls"].first

        # Prioritize 'url' if available, as the input was a URL.
        if first_result.is_a?(Hash) && first_result["url"]
          Rails.logger.info "Bria AI returned image URL: #{first_result['url']}"
          modified_image_url = first_result["url"]
        elsif first_result.is_a?(Hash) && first_result["b64_json"]
          # Fallback: If Bria AI returns Base64, upload it to Active Storage.
          Rails.logger.info "Bria AI returned Base64 image, uploading to Active Storage."
          decoded_image = Base64.decode64(first_result["b64_json"])

          # Create a temporary file to store the decoded image.
          temp_file = Tempfile.new([ "bria_ai_modified_", ".png" ], binmode: true)
          temp_file.write(decoded_image)
          temp_file.rewind # Rewind to the beginning of the file before reading.

          # Upload the temporary file to Active Storage.
          modified_blob = ActiveStorage::Blob.create_and_upload!(
            io: temp_file,
            filename: "bria_ai_modified_#{SecureRandom.hex(8)}.png",
            content_type: "image/png" # Assuming PNG, adjust if API provides content type.
          )
          modified_image_url = modified_blob.url # Get the public URL from Active Storage.

          temp_file.close # Close the temporary file handle.
          temp_file.unlink # Delete the temporary file from the file system.
        elsif first_result.is_a?(String) # Handle case where 'urls' directly contains string URLs
            Rails.logger.info "Bria AI returned direct image URL: #{first_result}"
            modified_image_url = first_result
        else
          # Handle cases where the expected output format is not found.
          raise BriaAI::APIError, "Bria AI response did not contain expected image output (url or b64_json) in 'urls' array."
        end
      else
        # Log and raise an error if the API response indicates failure or is empty.
        Rails.logger.error "Bria AI response was unsuccessful or empty: #{bria_response.body.inspect}"
        raise BriaAI::APIError, "Bria AI API call failed or returned no results. Response: #{bria_response.body.inspect}"
      end

      # 3. Broadcast the result back to the frontend via Action Cable.
      ActionCable.server.broadcast(
        "landscaper_channel", # Ensure this matches the channel subscribed to on the frontend.
        { modified_image_url: modified_image_url }
      )
      Rails.logger.info "Image modification job completed for #{original_image_url}. Result broadcasted: #{modified_image_url}"

    # --- Error Handling for Bria AI Specific Errors ---
    rescue BriaAI::AuthenticationError => e
      Rails.logger.error "Bria AI Authentication Error for #{original_image_url}: #{e.message}"
      ActionCable.server.broadcast(
        "landscaper_channel",
        { error: "Authentication failed with Bria AI. Please check your API token." }
      )
    rescue BriaAI::RateLimitError => e
      Rails.logger.warn "Bria AI Rate Limit Exceeded for #{original_image_url}: #{e.message}"
      ActionCable.server.broadcast(
        "landscaper_channel",
        error: "Bria AI rate limit exceeded. Please try again shortly."
      )
      # Optionally re-raise the exception here if you want ActiveJob's built-in retry
      # mechanism to handle retrying this job after a delay.
      # raise # Uncomment to re-raise and allow ActiveJob to retry if configured.
    rescue BriaAI::APIError => e
      Rails.logger.error "Bria AI API Error for #{original_image_url}: #{e.message}"
      ActionCable.server.broadcast(
        "landscaper_channel",
       { error: "Failed to process image with Bria AI: #{e.message}" }
      )
    rescue BriaAI::Error => e
      Rails.logger.error "General Bria AI error for #{original_image_url}: #{e.message}"
      ActionCable.server.broadcast(
        "landscaper_channel",
        { error: "An unexpected Bria AI service error occurred: #{e.message}" }
      )
    # --- General Error Handling ---
    rescue StandardError => e
      # Catch any other unexpected errors that might occur during job execution.
      Rails.logger.error "Image modification job failed for #{original_image_url}: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
      ActionCable.server.broadcast(
        "landscaper_channel",
        { error: "An unexpected error occurred during image modification: #{e.message}" }
      )
    end
  end

  private

  # This helper method processes the original_image_url to ensure it's in a format
  # suitable for the Bria AI API. If it's a local Active Storage path, it reads the
  # blob and encodes it to Base64. Otherwise, it returns the URL as is.
  # @param original_image_url [String] The URL of the original image.
  # @return [String] A public URL or a Base64 encoded string of the image.
  def prepare_original_image_for_bria(original_image_url)
    # Check if the URL looks like a local Active Storage path (e.g., "/rails/active_storage/blobs/...")
    if original_image_url.start_with?("/rails/active_storage/blobs/")
      Rails.logger.info "Detected Active Storage local URL for original image. Attempting to encode to Base64."

      # Extract the signed ID from the Active Storage URL
      # The signed ID is the part after "/rails/active_storage/blobs/" and before the last "/".
      # Example: "/rails/active_storage/blobs/eyJfcmFpbHMiOnsiZGF0YSI6NTEsInB1ciI6ImJsb2JfaWQifX0=--ef0d1b48b4f4298e8bacfa4ba34f75b7ada2f865/avatar.jpg"
      # The part we need is "eyJfcmFpbHMiOnsiZGF0YSI6NTEsInB1ciI6ImJsb2JfaWQifX0=--ef0d1b48b4f4298e8bacfa4ba34f75b7ada2f865"
      signed_id = original_image_url.split("/")[4..-2].join("/") rescue nil

      unless signed_id
        Rails.logger.error "Could not extract signed_id from Active Storage URL: #{original_image_url}"
        raise ArgumentError, "Invalid Active Storage URL format for original image."
      end

      # Find the ActiveStorage::Blob using the signed ID
      # Use `ActiveStorage::Blob.find_signed!` for robust lookup.
      blob = ActiveStorage::Blob.find_signed!(signed_id)

      # Read the content of the blob and Base64 encode it.
      # `blob.download` reads the content directly.
      encoded_image_data = Base64.strict_encode64(blob.download)
      Rails.logger.info "Successfully encoded Active Storage image to Base64."
      encoded_image_data
    else
      # If it's not an Active Storage local path, assume it's already a public URL.
      Rails.logger.info "Original image URL is not an Active Storage local URL, treating as public URL."
      original_image_url
    end
  rescue ActiveStorage::FileNotFoundError => e
    Rails.logger.error "Active Storage file not found for URL #{original_image_url}: #{e.message}"
    raise BriaAI::Error, "Original image file not found in Active Storage: #{e.message}"
  rescue ArgumentError => e
    # Catching the ArgumentError raised for invalid URL format or other parsing issues
    Rails.logger.error "Error preparing original image for Bria AI: #{e.message}"
    raise BriaAI::Error, "Error preparing original image for Bria AI: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Unexpected error in prepare_original_image_for_bria: #{e.class}: #{e.message}"
    raise BriaAI::Error, "An unexpected error occurred while preparing the original image: #{e.message}"
  end

  def flip_mask_colors(data_url)
    # Ensure the data_url starts with "data:image/png;base64,"
    unless data_url.start_with?("data:image/png;base64,")
      raise ArgumentError, "Invalid data_url format. Expected 'data:image/png;base64,' prefix."
    end

    # Extract the base64 part of the data URL
    _mime_type, base64_data = data_url.split(",", 2)

    if base64_data.nil?
      raise ArgumentError, "Could not extract base64 data from the provided URL."
    end

    # Decode the base64 string into binary image data
    decoded_image_data = Base64.decode64(base64_data)

    begin
      # Use MiniMagick to read the image from the binary data
      # The `read` method can take a binary string or a file path.
      image = MiniMagick::Image.read(decoded_image_data)

      # Invert the colors of the image.
      # For a black and white mask, `negate` will turn black pixels white and white pixels black.
      image.negate

      # Convert the modified image back to a binary string (PNG format is typically preserved)
      inverted_image_binary_data = image.to_blob

      # Encode the binary data back to base64
      inverted_base64 = Base64.encode64(inverted_image_binary_data)

      # Return the new base64 encoded image as a data URL, preserving the PNG mime type
      "data:image/png;base64,#{inverted_base64}"
    rescue MiniMagick::Error => e
      raise "Image processing error with MiniMagick: #{e.message}. " \
            "Please ensure ImageMagick is correctly installed and accessible on your system."
    rescue => e
      raise "An unexpected error occurred during mask color flipping: #{e.message}"
    end
  end
end
