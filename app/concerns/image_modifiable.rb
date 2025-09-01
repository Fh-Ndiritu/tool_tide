module ImageModifiable
  extend ActiveSupport::Concern

  def validate_mask_data
    # we shall ensure the mask has at least 10 % black pixels
    blob = build_mask_blob
    raise "Please draw the area to style on the image..." unless blob

    threshold = 5
    image = MiniMagick::Image.read(blob.download) do |img|
      img.colorspace("Gray").threshold("50%")
    end

    mean = image.data.dig("channelStatistics", "gray", "mean")
    max = image.data.dig("channelStatistics", "gray", "max")

    raise "Please draw the area to style on the image..." unless mean

    # Max will be 1 or 255 while mean at 0 means all black while at 1/255 means all white
    black_percentage = (max - mean).to_f / max * 100

    raise "Please draw the area to style on the image..." unless black_percentage >= threshold
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
end
