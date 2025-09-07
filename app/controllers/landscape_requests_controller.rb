# frozen_string_literal: true

class LandscapeRequestsController < ApplicationController
  include Notifiable

  before_action :set_landscape_request, only: %i[location edit update low_credits]
  before_action :handle_downgrade_notifications, only: %i[edit update]

  def low_credits; end

  def location
    if location_params.present?
      results = Geocoder.search([location_params[:latitude], location_params[:longitude]])
      current_user.update!(location_params)

      current_user.update! address: results.first&.data&.dig("address") if results.present?
      @landscape_request.toggle!(:use_location)
    end
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(:local_location, partial: "/landscape_requests/location",
                                                                   locals: { landscape_request: @landscape_request, current_user: })
      end
    end
  end

  def edit
    @canvas = canvas_dimensions
    @landscape = @landscape_request.landscape
  end

  def update
    ActiveRecord::Base.transaction do
      prompt = fetch_prompt
      @landscape_request.update!(prompt:, preset: landscape_request_params[:preset])
      @landscape_request.set_default_image_processor!
      save_mask
    end

    if current_user.afford_generation?(@landscape_request)
      ImageModificationJob.perform_now(@landscape_request.id)
      render json: { message: "Image modification request received. Processing in background." }, status: :accepted
    else
      render json: { error: "You are running low on free engine credits. Please check back tomorrow for more free credits or upgrade to Pro." },
             status: :unauthorized
    end
  rescue StandardError => e
    render json: { error: "Internal server error: #{e.message}" }, status: :internal_server_error
  end

  private

  def save_mask
    # Check if a mask image is present in the parameters
    return if landscape_request_params[:mask].blank?

    # Extract mime type and Base64 content from the data URL
    _mime_type, base64_content = landscape_request_params[:mask].split(",", 2)

    # Decode the Base64 content and wrap it in a StringIO object
    decoded_mask_data = Base64.decode64(base64_content)
    io_object = StringIO.new(decoded_mask_data)

    # Attach the mask directly to the landscape request record
    @landscape_request.mask.attach(
      io: io_object,
      filename: "mask.png",
      content_type: "image/png"
    )

    # Save the record
    @landscape_request.save!
  rescue StandardError => e
    # Log the error and re-raise with a more descriptive message
    Rails.logger.error "Failed to save mask: #{e.message}"
    raise "Failed to save mask: #{e.message}"
  end

  def location_params
    params.permit(:latitude, :longitude).compact_blank.transform_values(&:to_d)
  end

  def set_landscape_request
    @landscape_request = LandscapeRequest.includes(:landscape).find(params[:id])
  end

  def landscape_request_params
    params.require(:landscape_request).permit(:preset, :mask)
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
    raise "Invalid landscape vibe selected." if LANDSCAPE_PRESETS[preset].blank?

    # we now fetch the prompt from prompts.yml
    prompt = PROMPTS["landscape_presets"][preset]
    raise "Preset prompts not found." if prompt.blank?

    prompt
  end
end
