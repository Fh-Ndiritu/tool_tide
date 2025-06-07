# frozen_string_literal: true

# This will run on mistral and will be responsible for extracting text from images

class Images::ImageTextExtractor
  include Markdownable
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/jpg].freeze
  def initialize(images)
    # these images are ActionDispatch::Http::UploadedFile objects from the form
    @images = remove_invalid_images(images)
  end

  def self.perform(*args)
    new(*args).perform
  end

  def perform
    # resize the image
    # pass to mistral
    # get back markdown
    # pass to kramdown for html
    # integrate Latex and JS
    # render text as html
    # give copy option

    data = []
    uploaded_image = @images.first

    @images.each do |uploaded_image|
      encoded_image = resize_encode_image(uploaded_image)
      result = ExternalClients::MistralService.instance.image_ocr(encoded_image)
      next unless result.success?

      # we only need to handle our markdown on page one
      text = kramdown_markdown(result.data["pages"][0])


      # we now have valid html. It needs some js libraries to display well
      data << [ text, uploaded_image.original_filename ]
    end
    Result.new(success: true, data:)
  rescue StandardError => e
    Result.new(success: false, error: "Error extracting text from image: #{e.message}")
  end

  private

  def resize_encode_image(uploaded_image)
    # we shall use JPEG files to keep inputs consistent
    pipeline = ImageProcessing::Vips.source(uploaded_image.tempfile)
    tempfile = pipeline.convert("jpeg").resize_to_limit!(700, 700)
    Base64.strict_encode64(tempfile.read)
  rescue StandardError => e
    raise "Error resizing and encoding image: #{e.message}"
  end

  def remove_invalid_images(images)
    images.filter_map do |image|
      next if image.blank?
      next unless image.is_a?(ActionDispatch::Http::UploadedFile) && image.content_type.in?(IMAGE_CONTENT_TYPES)
      image
    end

  rescue StandardError => e
    raise "Error filtering images: #{e.message}"
  end
end
