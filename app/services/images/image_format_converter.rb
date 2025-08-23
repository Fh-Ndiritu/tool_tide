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

  # Formats for which Vips might struggle or ImageMagick is generally better,
  # especially for older/niche formats or specific features.
  # This list comes directly from your test results where Vips failed but Magick succeeded.
  VIPS_FALLBACK_FORMATS = %w[heic heif pcx xbm xpm].freeze

  # Formats that neither Vips nor MiniMagick can directly convert raster to vector.
  # SVG is the primary example here.
  UNSUPPORTED_RASTER_TO_VECTOR_FORMATS = %w[svg].freeze

  def perform
    output_path = generate_output_path(@image_file.original_filename, @target_format).to_s

    # 1. Check for unsupported raster-to-vector conversions
    if UNSUPPORTED_RASTER_TO_VECTOR_FORMATS.include?(@target_format.downcase)
      return Result.new(
        success: false,
        error: "Conversion failed: Converting raster images (like JPG) to vector format " \
               "(#{@target_format.upcase}) is not directly supported by image processing libraries. " \
               "Requires specialized vectorization."
      )
    end

    begin
      # Attempt conversion with Vips first
      ImageProcessing::Vips
        .source(@image_file.path)
        .convert(@target_format)
        .call(destination: output_path)

      # If Vips succeeds, return success
      Result.new(success: true, data: { converted_file_path: output_path })

    rescue ImageProcessing::Error => e
      # If Vips fails for a known fallback format, try MiniMagick
      if VIPS_FALLBACK_FORMATS.include?(@target_format.downcase)
        Rails.logger.warn "Vips conversion failed for #{@target_format}: #{e.message}. Falling back to MiniMagick."
        begin
          ImageProcessing::MiniMagick
            .source(@image_file.path)
            .convert(@target_format)
            .call(destination: output_path)

          # If MiniMagick succeeds, return success
          Result.new(success: true, data: { converted_file_path: output_path })

        rescue ImageProcessing::Error => mm_e
          # MiniMagick also failed
          Result.new(success: false, error: "Image processing failed with both Vips and MiniMagick: #{mm_e.message}. (Original Vips error: #{e.message})")
        end
      else
        # Vips failed for a format not in our fallback list
        Result.new(success: false, error: "Image processing failed with Vips: #{e.message}")
      end
    rescue StandardError => e
      # Catch any other unexpected errors during the process (e.g., file system issues)
      Result.new(success: false, error: "An unexpected error occurred: #{e.message}")
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
