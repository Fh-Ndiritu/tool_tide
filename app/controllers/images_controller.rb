class ImagesController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :validate_source, only: [ :new ]
  before_action :validate_conversion, only: [ :new ]


  def index
    @converted_file_paths = flash[:converted_file_paths] || []
  end

  def extract_text
    @image_form = ImageExtractionForm.new
  end

  def extract
    @image_form = ImageExtractionForm.new(image_extraction_params)
    if @image_form.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("results",
                                                    partial: "images/results_extraction",
                                                    locals: { pages: @image_form.results }) +
                               turbo_stream.replace("image_form",
                                                    partial: "images/image_extraction_form",
                                                    locals: {
                                                      image_form: ImageExtractionForm.new
                                                        }) +
                               turbo_stream.replace("flash", partial: "/shared/flash")
        end
        format.html { redirect_to converted_images_path, notice: "Images converted successfully!" } # Redirect for non-Turbo Stream requests
      end
    else
      respond_to do |format|
        format.turbo_stream do
          flash.now[:error] = @image_form.errors.full_messages.join("<br>").html_safe
          render turbo_stream: turbo_stream.replace("flash", partial: "/shared/flash") +
                               turbo_stream.replace("image_form",
                                                    partial: "images/image_extraction_form",
                                                    locals: { image_form: @image_form }) # Re-render form with errors
        end
        format.html { render :new, status: :unprocessable_entity } # Re-render new template for HTML requests
      end
    end
  end

  def new
    if @conversion == @source
      redirect_to root_path, alert: "Source and conversion formats cannot be the same."
    end

    @image_form = ImageConversionForm.new(conversion: @conversion, source: @source)
  end

  def create
    @image_form = ImageConversionForm.new(image_conversion_params)
    @supported_formats = ImageFormatHelper.canonical_formats_list
    if @image_form.save
      respond_to do |format|
        format.turbo_stream do
          # Replace the results area with a partial that lists the converted files.
          # Use the canonical conversion format for the partial name as you specified (e.g., _results_jpeg.html.erb).
          # Pass the `converted_file_paths` from the form object.
          #
          # Then, re-render the image_form partial, passing the `@image_form`
          # (perhaps a fresh instance if you want to clear the form, or the same one for initial values)
          # and `@supported_formats`.
          # For a clear form after success, you might instantiate a new @image_form here:
          # @image_form = ImageConversionForm.new

          render turbo_stream: turbo_stream.replace("results",
                                                    partial: "images/results_conversion",
                                                    locals: { converted_file_paths: @image_form.conversion_results, canonical_conversion: @image_form.canonical_conversion }) +
                               turbo_stream.replace("image_form",
                                                    partial: "images/image_form",
                                                    locals: {
                                                      image_form: ImageConversionForm.new(
                                                        source: @image_form.source,
                                                        conversion: @image_form.conversion),
                                                        supported_formats: @supported_formats }
                                                        ) +
                               turbo_stream.replace("flash", partial: "/shared/flash")
        end
        format.html { redirect_to converted_images_path, notice: "Images converted successfully!" } # Redirect for non-Turbo Stream requests
      end
    else
      respond_to do |format|
        format.turbo_stream do
          flash.now[:error] = @image_form.errors.full_messages.join("<br>").html_safe
          render turbo_stream: turbo_stream.replace("flash", partial: "/shared/flash") +
                               turbo_stream.replace("image_form",
                                                    partial: "images/image_form",
                                                    locals: { image_form: @image_form, supported_formats: @supported_formats }) # Re-render form with errors
        end
        format.html { render :new, status: :unprocessable_entity } # Re-render new template for HTML requests
      end
    end
  end

  private

  def image_extraction_params
    # we need to filter out blank images
    params.require(:image_extraction_form).permit().merge(images: params[:image_extraction_form][:images].reject { |img| img.blank? })
  end

  def validate_conversion
    # =========================================================================
    # Use `canonical_format` to check if the conversion type is supported,
    # accounting for aliases and case-insensitivity.
    canonical_conversion = ImageFormatHelper.canonical_format(params[:conversion])

    if canonical_conversion && DESTINATION_IMAGE_FORMATS.include?(canonical_conversion)
      # Store the canonical format if it's valid.
      # This ensures consistency in subsequent logic (e.g., MiniMagick calls).
      @conversion = canonical_conversion
    else
      flash[:error] = "Invalid conversion type. Please provide a supported image format."
      redirect_to root_path
    end
  end

  def validate_source
    # Use `canonical_format` to check if the source type is supported,
    # accounting for aliases and case-insensitivity.
    canonical_source = ImageFormatHelper.canonical_format(params[:source])

    if canonical_source
      # Store the canonical format.
      @source = canonical_source
    else
      flash[:error] = "Invalid source type. Please provide a supported image format."
      redirect_to root_path
    end
  end

  def image_conversion_params
    params.require(:image_conversion_form).permit(
      :conversion,
      :source
    ).merge(images: params[:image_conversion_form][:images].reject { |img| img.blank? })
  end
end
