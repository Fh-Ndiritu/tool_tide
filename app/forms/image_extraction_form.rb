
# frozen_string_literal: true

# this returns boolean and instance value of [results array of [pages hash {with :text and :filename}]]
# results = [
# {text: "html", filename: "filename"}
# ]
require "mini_magick" # Ensure MiniMagick is available in your form object

class ImageExtractionForm
  include ActiveModel::Model # Provides validations, errors, etc.
  # include ActiveModel::Attributes # Uncomment if you want type casting (Rails 6.1+)

  # Attributes that will come from the form
  attr_accessor :images # `images` will be an array of ActionDispatch::Http::UploadedFile

  attr_reader :results

  # Initialize the form object with parameters from the controller
  def initialize(attributes = {})
    # Using `super` allows ActiveModel::Model to handle attribute assignment
    # if you're using ActiveModel::Attributes. Otherwise, manual assignment.
    # For now, let's stick to simple assignment.
    attributes.each do |name, value|
      send("#{name}=", value) if respond_to?("#{name}=")
    end
  end

  validates :images, presence: { message: "must be selected." } # Ensure at least one file is uploaded

  # Custom validations for format validity using our helper
  validate :all_images_valid

  # The core logic: process the conversions
  def save
    return false unless valid? # Always validate first

    # This array will store paths to successfully converted files or other results
    @results = []
    conversion_successful = true

    # Iterate through each uploaded image and attempt conversion
    images.each do |image_file|
      begin
        # Delegate the actual conversion to a service object
        # This keeps the form object focused on form logic, not file manipulation.
        # We'll create ImageConversionService next.
        result = Images::ImageTextExtractor.perform(image_file)

        if result.success?
          @results << result.data
        else
          # Add errors specific to this file conversion failure
          errors.add(:base, "Failed to convert #{image_file.original_filename}: #{result.error}")
          conversion_successful = false
        end
      rescue => e
        # Catch any unexpected errors during service call
        errors.add(:base, "An unexpected error occurred during conversion of #{image_file.original_filename}: #{e.message}")
        conversion_successful = false
      end
    end

    # Return overall success status
    conversion_successful
  end

  private
  # Custom validation to ensure all uploaded items are actual files and have reasonable content types
  def all_images_valid
    if images.present?
      images.each do |image_file|
        unless image_file.respond_to?(:path) && image_file.respond_to?(:content_type)
          errors.add(:images, "must be valid file uploads.")
          break # Stop checking if one is invalid
        end
        source = image_file.content_type
        unless ImageFormatHelper.extractable_format?(source)
          errors.add(:source, "'#{source}' is not a supported source format.")
          break
        end
      end
    end
  end
end
