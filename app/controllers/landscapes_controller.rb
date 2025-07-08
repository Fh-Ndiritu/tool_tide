class LandscapesController < ApplicationController
  # Protect from CSRF attacks
  skip_before_action :verify_authenticity_token, only: [ :create ]
  before_action :set_landscape, only: %i[show edit modify]

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
    update_prompt
    mask_image_data = landscape_params[:mask_image_data]

    if mask_image_data.blank?
      render json: { error: "Missing required parameters." }, status: :bad_request and return
    end

    # Enqueue the AI processing job
    # This job will handle fetching images, calling AI API, and uploading results
    # It will also broadcast updates via Action Cable
    ImageModificationJob.perform_now(@landscape.id, mask_image_data)

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
        # format.turbo_stream { render turbo_stream: turbo_stream.replace("new_landscape", partial: "landscapes/landscape", locals: { landscape: @landscape, canvas: }) }
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
    @landscape = Landscape.new
    @landscape.original_image.attach(original_image)
    @landscape.save
  end

  def canvas
    return {} unless @landscape.original_image.attached?

    blob = @landscape.original_image.blob
    blob.analyze unless blob.metadata[:width] && blob.metadata[:height]
    metadata = blob.metadata
    { width: metadata[:width], height: metadata[:height] }
  end

  def update_prompt
    preset = landscape_params[:preset]
    raise "Please select a landscape vibe" if preset.blank?
    raise "Invalid landscape vibe selected" unless LANDSCAPE_PRESETS[preset].present?

    # we now fetch the prompt from prompts.yml
    prompt = PROMPTS["landscape_presets"][preset]
    raise "Preset prompts not found" unless prompt.present?

    @landscape.update prompt: prompt
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
end
