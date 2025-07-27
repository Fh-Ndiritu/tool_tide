class LandscapesController < ApplicationController
  # Protect from CSRF attacks
  skip_before_action :verify_authenticity_token, only: [ :create ]
  before_action :set_landscape, only: %i[show edit modify]
  before_action :check_premium, only: %i[show modify]

  rate_limit to: 6,
  within: 1.minutes,
  with: -> {
    redirect_to root_path, alert: "Too many landscaping attempts! Try again later."
  },
  only: %i[create]

  def new
    @landscape = Landscape.new
    @canvas = canvas
  end

  def show
  end

  def edit
    @canvas = canvas
  end

  def modify
    create_landscape_request
    mask_image_data = landscape_params[:mask_image_data]

    if mask_image_data.blank?
      render json: { error: "Missing required parameters." }, status: :bad_request and return
    end

    # Enqueue the AI processing job
    # This job will handle fetching images, calling AI API, and uploading results
    # It will also broadcast updates via Action Cable
    # unless @landscape.mask_image_data.attached?

    save_mask(mask_image_data)
    ImageModificationJob.perform_now(@landscape.id)

    # Respond immediately to the frontend to indicate job acceptance
    render json: { message: "Image modification request received. Processing in background." }, status: :accepted
  rescue StandardError => e
    Rails.logger.error "Error in modify_image endpoint: #{e.message}"
    render json: { error: "Internal server error: #{e.message}" }, status: :internal_server_error
  end

  def create
    original_image = params.dig(:landscape, :original_image)
    if original_image.present?
      create_landscape(original_image)
      width = params.dig(:landscape, :device_width).to_i
      LandscaperImgResizerJob.perform_now(@landscape.id, @landscape.original_image.to_sgid.to_s, width)
      respond_to do |format|
        format.html { redirect_to edit_landscape_path(@landscape) }
      end
    else
      flash[:alert] = "Please upload an image"
      redirect_to landscapes_path
    end
  end

  def show
  end


  private

  def create_landscape(original_image)
    @landscape = Landscape.new(ip_address: request&.remote_ip)
    @landscape.original_image.attach(original_image)
    @landscape.save
  end

  def canvas
    return {} unless @landscape.original_responsive_image.attached?

    blob = @landscape.original_responsive_image.blob
    blob.analyze unless blob.metadata[:width] && blob.metadata[:height]
    metadata = blob.metadata
    { width: metadata[:width], height: metadata[:height] }
  end

  def create_landscape_request
    preset = landscape_params[:preset]
    raise "Please select a landscape vibe" if preset.blank?
    raise "Invalid landscape vibe selected" unless LANDSCAPE_PRESETS[preset].present?

    # we now fetch the prompt from prompts.yml
    prompt = PROMPTS["landscape_presets"][preset]
    raise "Preset prompts not found" unless prompt.present?

    @landscape.landscape_requests.create(prompt:, image_engine: "bria", preset: preset.humanize)
  end

  def set_landscape
    @landscape = Landscape.find(params[:id])
    unless @landscape.original_image.attached?
      flash[:alert] = "No image found for this landscape"
      redirect_to landscapes_path
    end
  end

  def landscape_params
    params.require(:landscape).permit(:original_image, :preset, :mask_image_data)
  end

  def save_mask(raw_mask_image_data)
    # Extract base64 content and decode
    # we need to resize this to match the size of the final image
    _mime_type, base64_content = raw_mask_image_data.split(",", 2)
    decoded_mask = Base64.decode64(base64_content)

    original_image_data = @landscape.original_image.variant(:final).processed.download
    original_image = MiniMagick::Image.read(original_image_data)

    mask_image = MiniMagick::Image.read(decoded_mask)

    unless original_image.dimensions == mask_image.dimensions
      mask_image.resize "#{original_image.width}x#{original_image.height}!"
    end

    mask_image.format "png"

    io = StringIO.new(mask_image.to_blob)

    # Attach the mask to the landscape record
    @landscape.mask_image_data.attach(
      io: io,
      filename: "mask_#{SecureRandom.hex(8)}.png",
      content_type: "image/png"
    )
    Rails.logger.info "Mask image data saved to Active Storage for Landscape ID: #{@landscape.id}"
  rescue => e
    Rails.logger.error "Failed to save mask_image_data for Landscape ID #{@landscape.id}: #{e.message}"
    # For now, we'll log and continue, as the AI processing might still work even if mask saving fails.
  end

  def check_premium
    # We check if the user has more than 2 successul requests that happened in the last 24 hrs
    # IF false, we allow use of premium models
    if request&.remote_ip.present?
      recent_requests = LandscapeRequest.joins(:landscape).where(
                          created_at: 24.hours.ago..,
                          image_engine: :google,
                          landscape: { ip_address: request&.remote_ip }
                          )
      if recent_requests&.count < 2
        @reverted_to_bria = (recent_requests.count == 2)
        @image_engine = "google"
        return
      end

    end

    @reverted_to_bria = false
    @image_engine = "bria"
  end
end
