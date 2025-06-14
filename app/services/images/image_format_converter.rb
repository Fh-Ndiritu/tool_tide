# frozen_string_literal: true

# returns the data with output path and original filename
module Images
  class ImageFormatConverter
    def initialize(target_format, image_file)
      @target_format = target_format
      @image_file = image_file
    end

    def self.perform(*args)
      new(*args).perform
    end

    def perform
      output_path = generate_output_path(@image_file.original_filename, @target_format)

      begin
        image = MiniMagick::Image.open(@image_file.path)
        image.format(@target_format)
        image.write(output_path)

        Result.new(success: true, data: { converted_file_path: output_path})
      rescue MiniMagick::Invalid => e
        Result.new(success: false, error: "Invalid image file or unsupported format. Details: #{e.message}")
      rescue StandardError => e
        Result.new(success: false, error: "An unexpected error occurred during image processing. Details: #{e.message}")
      end
    end

    def generate_output_path(original_filename, target_format)
      # Ensure a unique filename and path to prevent overwrites
      basename = File.basename(original_filename, ".*")
      timestamp = Time.current.to_i
      unique_filename = "#{basename}_#{timestamp}.#{target_format}"
      # Use a temporary directory for processed files
      Rails.root.join("tmp", "conversions", unique_filename).tap do |path|
        FileUtils.mkdir_p(path.dirname) # Ensure the directory exists
      end
    end
  end
end
