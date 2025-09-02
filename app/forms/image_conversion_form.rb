# frozen_string_literal: true

require "mini_magick" # Ensure MiniMagick is available in your form object

class ImageConversionForm
  include ActiveModel::Model # Provides validations, errors, etc.
  # include ActiveModel::Attributes # Uncomment if you want type casting (Rails 6.1+)

  # Attributes that will come from the form
  attr_accessor :conversion, :source, :images # `images` will be an array of ActionDispatch::Http::UploadedFile

  # Canonical format values (determined during validation/processing)
  attr_reader :canonical_conversion, :canonical_source, :conversion_results

  # Initialize the form object with parameters from the controller
  def initialize(attributes = {})
    # Using `super` allows ActiveModel::Model to handle attribute assignment
    # if you're using ActiveModel::Attributes. Otherwise, manual assignment.
    # For now, let's stick to simple assignment.
    attributes.each do |name, value|
      send("#{name}=", value) if respond_to?("#{name}=")
    end
  end

  # --- Validations ---
  validates :conversion, presence: true
  validates :source, presence: true
  validates :images, presence: { message: "must be selected." } # Ensure at least one file is uploaded

  # Custom validations for format validity using our helper
  validate :supported_conversion_format
  validate :supported_source_format
  validate :all_images_valid

  # The core logic: process the conversions
  def save
    return false unless valid? # Always validate first

    # Ensure canonical formats are set for internal use
    @canonical_conversion = ImageFormatHelper.canonical_format(conversion)
    @canonical_source = ImageFormatHelper.canonical_format(source)

    # This array will store paths to successfully converted files or other results
    @conversion_results = []
    conversion_successful = true

    # Iterate through each uploaded image and attempt conversion
    images.each do |image_file|
      # Delegate the actual conversion to a service object
      # This keeps the form object focused on form logic, not file manipulation.
      # We'll create ImageConversionService next.
      result = Images::ImageFormatConverter.perform(@conversion, image_file)

      if result.success?
        @conversion_results << result.data[:converted_file_path]
      else
        # Add errors specific to this file conversion failure
        errors.add(:base, "Failed to convert #{image_file.original_filename}: #{result.error}")
        conversion_successful = false
      end
    rescue StandardError => e
      # Catch any unexpected errors during service call
      errors.add(:base,
                 "An unexpected error occurred during conversion of #{image_file.original_filename}: #{e.message}")
      conversion_successful = false
    end

    # Return overall success status
    conversion_successful
  end

  private

  # Custom validation to ensure the target conversion format is supported
  def supported_conversion_format
    return if conversion.blank?
    return if ImageFormatHelper.canonical_format(conversion)

    errors.add(:conversion, "'#{conversion}' is not a supported target format.")
  end

  # Custom validation to ensure the source format is supported
  def supported_source_format
    return if source.blank?
    return if ImageFormatHelper.canonical_format(source)

    errors.add(:source, "'#{source}' is not a supported source format.")
  end

  # Custom validation to ensure all uploaded items are actual files and have reasonable content types
  def all_images_valid
    return if images.blank?

    images.each do |image_file|
      unless image_file.respond_to?(:path) && image_file.respond_to?(:content_type)
        errors.add(:images, "must be valid file uploads.")
        break # Stop checking if one is invalid
      end

      # You might want to add more specific content type checks here
      # E.g., if you only allow certain MIME types as input
      # unless ImageFormatHelper.mime_type_for_file(image_file.content_type) # Hypothetical helper
      #   errors.add(:images, "contains an unsupported file type: #{image_file.original_filename}")
      # end
    end
  end
end
