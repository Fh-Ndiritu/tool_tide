class LandscapesController < ApplicationController
  # Protect from CSRF attacks
  skip_before_action :verify_authenticity_token, only: [ :create ]
  before_action :set_landscape, only: %i[show edit]
  before_action :set_landscape_request, only: %i[edit]
  before_action :issue_daily_credits, only: :new

  rate_limit to: 6,
  within: 1.minutes,
  with: -> {
    redirect_to root_path, alert: "Too many landscaping attempts! Try again later."
  },
  only: %i[create]

  def index
    @landscapes = current_user.landscapes
  end

  def new
    @landscape = current_user.landscapes.new
  end

  def show
  end

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

  def show
  end


  private

  def set_landscape_request
    @landscape_request = @landscape.landscape_requests.unclaimed.last || @landscape.landscape_requests.create
  end

  def create_landscape(original_image)
    @landscape = current_user.landscapes.new(ip_address: request&.remote_ip)
    @landscape.original_image.attach(original_image)
    @landscape.save
  end

  def set_landscape
    @landscape = current_user.landscapes.find(params[:id])
    unless @landscape.original_image.attached?
      flash[:alert] = "No image found for this landscape"
      redirect_to landscapes_path
    end
  end

  def issue_daily_credits
    current_user.issue_daily_credits unless current_user.received_daily_credits?
  end
end
