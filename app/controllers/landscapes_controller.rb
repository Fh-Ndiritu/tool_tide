# frozen_string_literal: true

class LandscapesController < ApplicationController
  include Notifiable

  skip_before_action :verify_authenticity_token, only: [ :create ]
  before_action :set_landscape, only: %i[show edit]
  before_action :set_landscape_request, only: %i[edit]
  before_action :issue_daily_credits, only: :new
  before_action :handle_downgrade_notifications, only: %i[new edit show]

  rate_limit to: 6,
             within: 1.minute,
             with: lambda {
               redirect_to root_path, alert: "Too many landscaping attempts! Try again later."
             },
             only: %i[create]

  def index
    @landscapes = current_user.complete_landscapes
  end

  def new
    @landscape = current_user.landscapes.new
  end

  def show; end

  def edit
    redirect_to edit_landscape_request_path(@landscape_request)
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

  def show; end

  private

  def set_landscape_request
    @landscape_request = @landscape.landscape_requests.unclaimed.last || @landscape.landscape_requests.create
  end

  def create_landscape(original_image)
    current_user.update ip_address: request&.remote_ip
    @landscape = current_user.landscapes.create
    @landscape.original_image.attach(original_image)
    @landscape.save
  end

  def set_landscape
    @landscape = current_user.landscapes.find(params[:id])
    return if @landscape.original_image.attached?

    flash[:alert] = "No image found for this landscape"
    redirect_to landscapes_path
  end

  def issue_daily_credits
    current_user.issue_daily_credits unless current_user.received_daily_credits?
  end
end
