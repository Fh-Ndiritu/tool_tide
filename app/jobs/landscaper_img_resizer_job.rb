class LandscaperImgResizerJob < ApplicationJob
  queue_as :default

  def perform(landscape_id, attachment_sgid, max_width = 700)
    landscape = Landscape.find_by(id: landscape_id)
    return unless landscape

    # Re-find the attachment using its SGID to ensure it's still present
    original_attachment = ActiveStorage::Attachment.find_by_id(GlobalID::Locator.locate_signed(attachment_sgid)&.id)

    return unless original_attachment&.blob&.persisted?

    temp_file = nil
    # Download the original image to a temporary file
    # This is crucial for ImageProcessing to work with the file system
    original_attachment.blob.open do |file|
      begin
        temp_file = file # `file` here is a Tempfile

        # Process the image using ImageProcessing::Vips
        processed_image = ImageProcessing::Vips
                          .source(temp_file)
                          .convert('jpeg')
                          .resize_to_fit(nil, max_width)
                          .call

        # Attach the processed image to the :processed_image attachment
        landscape.original_image.attach(
          io: File.open(processed_image.path),
          filename: "#{original_attachment.filename.base}.jpeg", # Ensure .jpg extension
          content_type: 'image/jpeg'
        )
      rescue ImageProcessing::Error => e
        Rails.logger.error "Image processing failed for Landscape ID: #{landscape_id}, Attachment SGID #{attachment_sgid}: #{e.message}"
      ensure
        processed_image.close! if processed_image.respond_to?(:close!)
        temp_file.close! if temp_file.respond_to?(:close!)
      end
    end
end
end
