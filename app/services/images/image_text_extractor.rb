# frozen_string_literal: true

# This will run on mistral and will be responsible for extracting text from images

class Images::ImageTextExtractor
  include Markdownable
  def initialize(image)
    # these images are ActionDispatch::Http::UploadedFile objects from the form
    @image = image
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

    encoded_image = resize_encode_image(@image)
    result = ExternalClients::MistralService.instance.image_ocr(encoded_image)
    return result unless result.success?

    # we only need to handle our markdown on page one
    text = kramdown_markdown(result.data['pages'][0])

    # we now have valid html. It needs some js libraries to display well
    Result.new(success: true, data: { text:, file_name: @image.original_filename })
  rescue StandardError => e
    Result.new(success: false, error: "Error extracting text from image: #{e.message}")
  end

  private

  def resize_encode_image(uploaded_image)
    # we shall use JPEG files to keep inputs consistent
    pipeline = ImageProcessing::Vips.source(uploaded_image.tempfile)
    tempfile = pipeline.convert('jpeg').resize_to_limit!(700, 700)
    Base64.strict_encode64(tempfile.read)
  rescue StandardError => e
    raise "Error resizing and encoding image: #{e.message}"
  end
end
