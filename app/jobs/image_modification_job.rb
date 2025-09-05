# frozen_string_literal: true

# app/jobs/image_modification_job.rb
require "mini_magick"

class ImageModificationJob < ApplicationJob
  queue_as :default
  include ImageModifiable
  include ErrorHandler

  # we validate mask
  # we generate custom prompts

  def perform(landscape_request_id)
    @landscape_request = LandscapeRequest.includes(landscape: :user).find(landscape_request_id)
    @user = @landscape_request.user
    @landscape = @landscape_request.landscape
    @landscape_request.update progress: :uploading, error: nil

    prepare_image_and_prompt

    @landscape_request.preparing_request!
    if @landscape_request.google_processor?
      Processors::GoogleV2.perform(@landscape_request.id)
    else
      Processors::Bria.perform(@landscape_request.id)
    end
    charge_user if @landscape_request.reload.processed?
    @landscape_request.complete!
    broadcast_success
  rescue StandardError => e
    @landscape_request.update progress: :failed, error: e.message
    broadcast_error(e)
  end

  private

  def prepare_image_and_prompt
    unless @landscape.original_image.attached?
      raise "Original image is not attached for landscape_blob: #{@landscape.id}."
    end

    @landscape_request.update!(error: nil, progress: :validating_drawing)
    validate_mask_data

    @landscape_request.suggesting_plants!
    fetch_localized_prompt
    @landscape_request.preparing_request!
  end

  def fetch_localized_prompt
    return unless @landscape_request.use_location?
    return if @landscape_request.localized_prompt.present?

    @landscape_request.suggesting_plants!
    @landscape_request.build_localized_prompt!
  end

  def charge_user
    @user.charge_image_generation!(@landscape_request)

    return unless @landscape_request.google_processor?

    @user.schedule_downgrade_notification unless @user.sufficient_pro_credits?
  end

  def broadcast_error(error)
    message = displayable_error?(error) ? error.message : "Something went wrong. Try submitting again..."
    ActionCable.server.broadcast(
      "landscape_channel_#{@landscape.id}",
      { error: message }
    )
  end

  def broadcast_success
    ActionCable.server.broadcast(
      "landscape_channel_#{@landscape.id}",
      { status: "completed", landscape_id: @landscape.id }
    )
  end
end
