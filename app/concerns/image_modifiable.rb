# frozen_string_literal: true

module ImageModifiable
  extend ActiveSupport::Concern

  def save_partial_blend
    # Get the parent landscape from the request
    @landscape_request = LandscapeRequest.last
    landscape = @landscape_request.landscape
    # Drop into a debugging session at the start of the method.

    # Create an array to hold our tempfiles for final cleanup.
    tempfiles_to_clean = []

    begin
      # Read the original image and the mask image from their blobs.
      original_image_data = landscape.original_image.variant(:to_process).processed
      original_image = MiniMagick::Image.read(original_image_data.blob.download)
      mask_binary = @landscape_request.mask.download
      mask_image = MiniMagick::Image.read(mask_binary)

      # Ensure the mask and original image have the same dimensions.
      unless original_image.dimensions == mask_image.dimensions
        mask_image.resize "#{original_image.width}x#{original_image.height}!"
      end
      attach_debug_blob(original_image, "original_image")
      attach_debug_blob(mask_image, "mask_image")

      # 1. Create a transparency mask for the original image.
      alpha_mask = mask_image.dup
      alpha_mask.combine_options do |c|
        c.colorspace("Gray")
        c.channel("alpha")
        c.fx("102*(1-u)") # Makes black areas 60% opaque and white areas transparent.
      end
      attach_debug_blob(alpha_mask, "alpha_mask_prepared")

      # Use a Tempfile for the alpha mask.
      alpha_mask_temp = Tempfile.create([ "alpha_mask", ".png" ])
      tempfiles_to_clean << alpha_mask_temp
      alpha_mask.write(alpha_mask_temp.path)
      alpha_mask_image = MiniMagick::Image.open(alpha_mask_temp.path)

      # 2. Create a solid green overlay.
      green_overlay = original_image.dup
      green_overlay.combine_options do |c|
        c.fill("lime")
        c.colorize("100%")
      end
      attach_debug_blob(green_overlay, "green_overlay_prepared")

      # 3. Create a transparency mask for the green overlay.
      green_mask = mask_image.dup
      green_mask.combine_options do |c|
        c.colorspace("Gray")
        c.negate # Invert the mask: white becomes black, black becomes white.
        c.channel("alpha")
        c.fx("u*255") # Makes white areas of the inverted mask opaque.
      end
      attach_debug_blob(green_mask, "green_mask_prepared")

      # Use a Tempfile for the green mask.
      green_mask_temp = Tempfile.create([ "green_mask", ".png" ])
      tempfiles_to_clean << green_mask_temp
      green_mask.write(green_mask_temp.path)
      green_mask_image = MiniMagick::Image.open(green_mask_temp.path)

      # Apply the green_mask_image object to the green_overlay.
      green_overlay.composite(green_mask_image) do |c|
        c.compose("CopyOpacity")
      end
      attach_debug_blob(green_overlay, "green_overlay_with_opacity")

      # Use a Tempfile for the green overlay.
      green_overlay_temp = Tempfile.create([ "green_overlay", ".png" ])
      tempfiles_to_clean << green_overlay_temp
      green_overlay.write(green_overlay_temp.path)
      green_overlay_image = MiniMagick::Image.open(green_overlay_temp.path)

      # 4. Composite the alpha mask onto the original image.
      original_image.composite(alpha_mask_image) do |c|
        c.compose("CopyOpacity")
      end
      attach_debug_blob(original_image, "original_image_alpha_blended")

      # 5. Composite the green overlay on top of the original image with the alpha mask.
      original_image.composite(green_overlay_image) do |c|
        c.compose("Over")
      end
      attach_debug_blob(original_image, "final_composite")

      # Save the resulting image to a blob.
      blob = attach_blob(original_image)
      @landscape_request.partial_blend.attach(blob)
    rescue StandardError => e
      Rails.logger.error "save_partial_blend failed: #{e.message}"
      raise "Failed to create partial blend: #{e.message}"

      # Clean up temporary files that were explicitly created.
      # tempfiles_to_clean.each do |temp|
      #   temp.unlink if temp && File.exist?(temp.path)
      # end
    end
  end

  # Helper method to attach an image for debugging purposes.
  def attach_debug_blob(image_object, step_name)
    blob_data = image_object.to_blob
    @landscape_request.partial_blend_debugs.attach(
      io: StringIO.new(blob_data),
      filename: "#{step_name}.png",
      content_type: "image/png"
    )
  rescue StandardError => e
    Rails.logger.error "Failed to attach debug image '#{step_name}': #{e.message}"
  end

  def validate_mask_data
    # we shall ensure the mask has at least 10 % black pixels
    blob = build_mask_blob
    raise I18n.t("permitted_errors.missing_drawing") unless blob

    threshold = 5
    image = MiniMagick::Image.read(blob.download) do |img|
      img.colorspace("Gray").threshold("50%")
    end

    mean = image.data.dig("channelStatistics", "gray", "mean")
    max = image.data.dig("channelStatistics", "gray", "max")

    raise I18n.t("permitted_errors.missing_drawing") unless mean

    # Max will be 1 or 255 while mean at 0 means all black while at 1/255 means all white
    black_percentage = (max - mean).to_f / max * 100

    raise I18n.t("permitted_errors.missing_drawing") unless black_percentage >= threshold
  end

  def build_mask_blob
    blob = @landscape_request.mask.blob
    original_image_data = @landscape.original_image.variant(:to_process).processed
    original_image = MiniMagick::Image.read(original_image_data.blob.download)
    mask_file = MiniMagick::Image.read(blob.download)
    return if original_image.dimensions == mask_file.dimensions

    mask_file.resize "#{original_image.width}x#{original_image.height}!"
    io_object = StringIO.new(mask_file.to_blob)

    blob = ActiveStorage::Blob.create_and_upload!(
      io: io_object,
      filename: "to_process.png",
      content_type: "image/png"
    )
    @landscape_request.mask.attach(blob)
    @landscape_request.save
    blob
  end

  def gsub_prompt(prompt)
    " DO NOT MODIFY THE UNMASKED AREAS OF THE IMAGE.
      Create a new image based on the original image, but only modify the areas defined by the black mask.
      Use professional plant, flower and feature placements that reflect a professional and intricate landscaper at work.
      #{prompt}
      If doors or entrances are present, add blending pathways that match this style.
      Use stones, lawns and pathways to improve the overall aesthetic.
      Ensure vibrant japanese plants and colors are used to enhance the overall aesthetic.
      Ensure photorealistic rendering of the landscape.
      8k resolution, highly detailed, photorealistic, vibrant colors.
      Ensure the final image is harmonious and visually appealing.

    "
  end

  def attach_blob(masked_image)
    io_object = StringIO.new(masked_image.to_blob)

    ActiveStorage::Blob.create_and_upload!(
      io: io_object,
      filename: "full_blend.png",
      content_type: "image/png"
    )
  end

  def initial_landscape_prompt
    @landscape_request.prompt
  end

  def rotated_landscape_prompt
    "Given this 8k highly detailed image of a landscaped garden compound, move the camera 120% horizontally to view the garden from a different angle.
  Ensure you do not add details that are outside the scope of the house, garden and compound. Return a highly resolution and professional looking angle."
  end

  def aerial_landscape_prompt
    "Given this image design of a well landscaped garden compound, change the perspective an aerial drone view to show the garden landscaping from above.
  Focus on the details of the garden and show the house in the periphery from above. This is an aerial view from a DJI drone perspective."
  end


    def save_b64_results(prediction)
      b64_data = prediction["data"]
      return if b64_data.blank?

      img_from_b64 = Base64.decode64(b64_data)
      extension = prediction["mimeType"].split("/").last

      temp_file = Tempfile.new([ "modified_image", ".#{extension}" ], binmode: true)
      temp_file.write(img_from_b64)
      temp_file.rewind

      blob = ActiveStorage::Blob.create_and_upload!(
        io: temp_file,
        filename: "modified_image.#{extension}",
        content_type: prediction["mimeType"]
      )
      @landscape_request.modified_images.attach(blob)
      @landscape_request.save!
    end

    def apply_mask_for_transparency
      original_image_data = @landscape.original_image.variant(:to_process).processed
      original_image = MiniMagick::Image.read(original_image_data.blob.download)

      mask_binary = @landscape_request.mask.download
      mask_image = MiniMagick::Image.read(mask_binary)

      unless original_image.dimensions == mask_image.dimensions
        mask_image.resize "#{original_image.width}x#{original_image.height}!"
      end

      save_full_blend(mask_image, original_image)
      @landscape_request.save!
    rescue StandardError => e
      raise "#{__method__} failed with: #{e.message}"
    end

        def save_full_blend(mask_image, original_image)
      mask_image.combine_options do |c|
        c.colorspace("Gray")
        c.threshold("50%")
      end

      mask_image.transparent("white")

      masked_image = original_image.composite(mask_image) do |c|
        c.compose "Over"
      end

      blob = attach_blob(masked_image)

      @landscape_request.full_blend.attach(blob)
    end
end
