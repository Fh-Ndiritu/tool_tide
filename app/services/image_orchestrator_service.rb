# frozen_string_literal: true

class ImageOrchestratorService
  def initialize(conversion, source, images, *args)
    @images = images
    @conversion = conversion
    @source = source
  end
  def self.perform(*args)
    new(*args).perform
  end

  def perform
    # here we shall handle the various types of conversions needed
    # for now we shall only handle text conversion
    case @conversion
    when 'text'
      Images::ImageTextExtractor.perform(@images)
    else
      Images::ImageFormatConverter.perform(@conversion, @images)
    end

  rescue StandardError => e
    Result.new(success: false, error: "Error performing image conversion: #{e.message}")
  end
end
