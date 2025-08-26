class LandscapeRequestsController < ApplicationController
  before_action :set_landscape_request, only: [ :location, :edit, :update ]

  def location
    if location_params.present?
      results = Geocoder.search([ location_params[:latitude], location_params[:longitude] ])
      current_user.update!(location_params)

      current_user.update! address: results.first&.data.dig("address") if results.present?
      @landscape_request.toggle!(:use_location)
    end
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(:local_location, partial: "/landscape_requests/location", locals: { landscape_request: @landscape_request, current_user: })
      end
    end
  end

  def edit
    @canvas = canvas_dimensions
    @landscape = @landscape_request.landscape
  end

  def update
    prompt = fetch_prompt
    validate_mask_image
    ActiveRecord::Base.transaction do
      @landscape_request.update!(prompt:,  preset: landscape_request_params[:preset].humanize)
      @landscape_request.set_default_image_processor!
      save_mask(landscape_request_params[:mask_image_data])
    end
    ImageModificationJob.perform_now(@landscape_request.id)

    # Respond immediately to the frontend to indicate job acceptance
    render json: { message: "Image modification request received. Processing in background." }, status: :accepted
  rescue StandardError => e
    Rails.logger.error "Error in modify_image endpoint: #{e.message}"
    render json: { error: "Internal server error: #{e.message}" }, status: :internal_server_error
  end

  private

def save_mask(raw_mask_image_data)
  # Log the start of the process
  Rails.logger.info "Starting save_mask for Landscape Request ID: #{@landscape_request.id}"

  begin
    # Extract base64 content and decode
    _mime_type, base64_content = raw_mask_image_data.split(",", 2)
    decoded_mask = Base64.decode64(base64_content)

    landscape = @landscape_request.landscape.reload
    raise "Original Image not found" unless landscape.original_image.attached?

    # Log the key step of downloading the variant
    Rails.logger.info "Original image attached. Attempting to download variant..."
    original_image_data = landscape.original_image.variant(:to_process).processed.download
    Rails.logger.info "Variant downloaded successfully. Size: #{original_image_data.bytesize} bytes."

    original_image = MiniMagick::Image.read(original_image_data)
    mask_image = MiniMagick::Image.read(decoded_mask)

    # Log the dimensions for comparison
    Rails.logger.info "Original dimensions: #{original_image.dimensions.join('x')}"
    Rails.logger.info "Mask dimensions: #{mask_image.dimensions.join('x')}"

    unless original_image.dimensions == mask_image.dimensions
      # Use a 'warn' log level for a non-critical but important event
      Rails.logger.warn "Mask dimensions mismatch. Resizing mask image to fit."
      mask_image.resize "#{original_image.width}x#{original_image.height}!"
    end

    mask_image.format "png"
    io = StringIO.new(mask_image.to_blob)

    # Attach the mask to the landscape record
    @landscape_request.mask_image_data.attach(
      io: io,
      filename: "mask_#{SecureRandom.hex(8)}.png",
      content_type: "image/png"
    )

    # Log the successful completion
    Rails.logger.info "Mask image data successfully saved to Active Storage."
  rescue => e
    # Use the 'error' log level to capture the exception message and backtrace
    Rails.logger.error "Failed to save mask: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise "Failed to save mask: #{e.message}"
  end
end

  def location_params
    params.permit(:latitude, :longitude).compact_blank.transform_values { |v| v.to_d }
  end

  def set_landscape_request
    @landscape_request ||= LandscapeRequest.includes(:landscape).find(params[:id])
  end

  def landscape_request_params
    params.require(:landscape_request).permit(:preset, :mask_image_data)
  end

  def canvas_dimensions
    return {} unless @landscape_request.landscape.original_responsive_image.attached?

    blob = @landscape_request.landscape.original_responsive_image.blob
    blob.analyze unless blob.metadata[:width] && blob.metadata[:height]
    metadata = blob.metadata
    { width: metadata[:width], height: metadata[:height] }
  end

  def fetch_prompt
    preset = landscape_request_params[:preset]
    raise "Please select a landscape vibe." if preset.blank?
    raise "Invalid landscape vibe selected." unless LANDSCAPE_PRESETS[preset].present?

    # we now fetch the prompt from prompts.yml
    prompt = PROMPTS["landscape_presets"][preset]
    raise "Preset prompts not found." unless prompt.present?
    prompt
  end

  def validate_mask_image
    mask_image_data = landscape_request_params[:mask_image_data]

    if mask_image_data.blank?
      raise "The drawing on the image is invalid!"
    end
  end
end
