class LandscaperController < ApplicationController
  # Protect from CSRF attacks
  skip_before_action :verify_authenticity_token, only: [ :modify_image ]
  before_action :fetch_prompt, only: :modify_image

  def index

  end

  def modify_image
    # This endpoint receives the image modification request from the frontend
    original_image_url = landscape_params[:original_image_url]
    mask_image_data = landscape_params[:mask_image_data] # Base64 encoded mask


    if original_image_url.blank? || mask_image_data.blank?
      render json: { error: "Missing required parameters." }, status: :bad_request and return
    end

    # Enqueue the AI processing job
    # This job will handle fetching images, calling AI API, and uploading results
    # It will also broadcast updates via Action Cable
    ImageModificationJob.perform_now(original_image_url, mask_image_data, @prompt)

    # Respond immediately to the frontend to indicate job acceptance
    render json: { message: "Image modification request received. Processing in background." }, status: :accepted
  rescue StandardError => e
    Rails.logger.error "Error in modify_image endpoint: #{e.message}"
    render json: { error: "Internal server error: #{e.message}" }, status: :internal_server_error
  end

  private

  def fetch_prompt
    preset = landscape_params[:preset]
    raise "Please select a landscape vibe" if preset.blank?
    raise "Invalid landscape vibe selected" unless LANDSCAPE_PRESETS[preset].present?

    # we now fetch the prompt from prompts.yml
    @prompt = PROMPTS["landscape_presets"][preset]
    raise "Preset prompts not found" unless @prompt.present?
  end


  def landscape_params
    params.require(:landscape).permit(:preset, :original_image_url, :mask_image_data)
  end
end
