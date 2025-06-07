# frozen_string_literal: true

class ImageOrchestratorService
  def initialize(conversion, images, *args)
    @images = images
    @conversion = conversion
  end
  def self.perform(*args)
    new(*args).perform
  end

  def perform
    # here we shall handle the various types of conversions needed
    # for now we shall only handle text conversion
    Images::ImageTextExtractor.perform(@images)
  rescue StandardError => e
    Result.new(success: false, error: "Error performing image conversion: #{e.message}")
  end
end
