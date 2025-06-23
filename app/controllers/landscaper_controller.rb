class LandscaperController < ApplicationController
  # Protect from CSRF attacks
  skip_before_action :verify_authenticity_token, only: [ :modify_image ]

  def index
    @url = ActiveStorage::Blob.first.url
  end

  def modify_image
    # This endpoint receives the image modification request from the frontend
    original_image_url = params[:original_image_url]
    mask_image_data = params[:mask_image_data] # Base64 encoded mask
    prompt = params[:prompt]

    if original_image_url.blank? || mask_image_data.blank? || prompt.blank?
      render json: { error: "Missing required parameters." }, status: :bad_request and return
    end

    # Enqueue the AI processing job
    # This job will handle fetching images, calling AI API, and uploading results
    # It will also broadcast updates via Action Cable
    ImageModificationJob.perform_now(original_image_url, mask_image_data, prompt)

    # Respond immediately to the frontend to indicate job acceptance
    render json: { message: "Image modification request received. Processing in background." }, status: :accepted
  rescue StandardError => e
    Rails.logger.error "Error in modify_image endpoint: #{e.message}"
    render json: { error: "Internal server error: #{e.message}" }, status: :internal_server_error
  end
end
