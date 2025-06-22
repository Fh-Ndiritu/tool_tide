# app/jobs/image_modification_job.rb
class ImageModificationJob < ApplicationJob
  queue_as :default # Or a specific queue for AI tasks

  def perform(original_image_url, mask_image_data, prompt)
    Rails.logger.info "Starting ImageModificationJob for #{original_image_url}"

    # 1. Decode mask image data (it's already Base64 from frontend)
    #    The frontend sends a mask that is the same dimensions as the original image.
    #    The prefix "data:image/png;base64," needs to be removed.
    mask_binary_data = Base64.decode64(mask_image_data.split(",")[1])

    # 2. (Optional) Process the mask if needed (e.g., invert colors for Leonardo AI)
    #    For Stable Diffusion, black pixels in the mask are replaced, which matches our frontend output.
    #    If integrating with Leonardo AI, you would invert the mask here using MiniMagick.
    #    Example for MiniMagick (ensure 'mini_magick' gem is in your Gemfile):
    #    require 'mini_magick'
    #    mask_image = MiniMagick::Image.read(mask_binary_data)
    #    if AI_API_REQUIRES_WHITE_MASK # Example condition for Leonardo AI
    #      mask_image.combine_options do |c|
    #        c.negate # Invert colors (black to white, white to black)
    #      end
    #    end
    #    processed_mask_data_url = "data:image/png;base64,#{Base64.strict_encode64(mask_image.to_blob)}"
    #    Otherwise, use mask_image_data directly if the AI API accepts Base64 directly.

    # For this example, we'll assume the AI API accepts the mask as a Base64 string directly
    # and that our frontend's black-for-replacement convention is compatible.
    # If the AI API requires a URL for the mask, you'd upload mask_binary_data to S3 first.

    # 3. Call the chosen AI API (e.g., Stable Diffusion, ModelsLab, Leonardo AI)
    #    Using http.rb or RubyLLM gem.
    #    Replace with actual API call logic.
    #    Example with Stable Diffusion API (assuming it accepts Base64 mask and URL for init_image):
    #    require 'http'
    #    response = HTTP.post("https://stablediffusionapi.com/api/v3/inpaint", json: {
    #      key: ENV, # Ensure this env var is set
    #      prompt: prompt,
    #      init_image: original_image_url,
    #      mask_image: mask_image_data, # Use the Base64 mask directly
    #      width: 1024, # Adjust based on desired output size and API limits
    #      height: 1024,
    #      samples: 1,
    #      base64: "no" # Request URL back
    #    })
    #    ai_response_data = JSON.parse(response.body.to_s)
    #    modified_image_url = ai_response_data['output'] # Adjust based on actual API response structure

    # Simulate AI processing time and result
    sleep(5) # Simulate AI processing time
    modified_image_url = "https://picsum.photos/600/1200" # Placeholder for modified image

    # 4. (Optional) Upload the modified image to Active Storage if the AI API returns Base64
    #    If the AI API returns a direct URL (like many do), you can just use that URL.
    #    If it returns Base64, you'd convert it to a file and attach it to an Active Storage blob.
    #    Example for Base64 response:
    #    require 'tempfile'
    #    require 'base64'
    #    decoded_image = Base64.decode64(ai_response_data['output_base64_string'])
    #    temp_file = Tempfile.new(['modified_image', '.png'], binmode: true)
    #    temp_file.write(decoded_image)
    #    temp_file.rewind
    #    modified_blob = ActiveStorage::Blob.create_and_upload!(
    #      io: temp_file,
    #      filename: "landscaped_#{SecureRandom.hex(8)}.png",
    #      content_type: 'image/png' # Or content_type from API response
    #    )
    #    modified_image_url = modified_blob.url # Get the public URL from Active Storage

    # 5. Broadcast the result back to the frontend via Action Cable
    ActionCable.server.broadcast(
      "landscaper_channel", # Ensure this matches the channel subscribed to on frontend
      modified_image_url: modified_image_url
    )
    Rails.logger.info "Image modification job completed for #{original_image_url}. Result broadcasted."
  rescue StandardError => e
    Rails.logger.error "Image modification job failed for #{original_image_url}: #{e.message}"
    ActionCable.server.broadcast(
      "landscaper_channel",
      error: "Failed to generate landscape: #{e.message}"
    )
  end
end
