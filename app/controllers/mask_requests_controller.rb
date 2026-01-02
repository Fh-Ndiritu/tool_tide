class MaskRequestsController < ApplicationController
  before_action :set_mask_request, only: %i[ show edit update destroy generate_planting_guide]
  before_action :set_canva, only: %i[new create update_location]
  skip_before_action :authenticate_user!, only: :explore

  # GET /mask_requests or /mask_requests.json
  def index
    @has_complete_sketches = SketchRequest.complete.joins(canva: :user).where(users: { id: current_user.id }).exists?

    if @has_complete_sketches && params[:tab] == "sketches"
      @sketch_requests = SketchRequest.complete.joins(canva: :user).where(users: { id: current_user.id }).order(id: :desc)
      @mask_requests = []
    else
      @mask_requests = MaskRequest.complete.joins(canva: :user).where(users: { id: current_user.id }).order(id: :desc)
      @sketch_requests = []
    end
  end

  def explore
    # canva_ids = Canva.joins(:user).where(user: { admin: true }).select(:id)
    @mask_requests = MaskRequest.complete.everyone.order(id: :desc).limit(40)
  end

  # GET /mask_requests/1 or /mask_requests/1.json
  def show
    puts "Show Flash: #{flash.to_hash}"
    @trigger_pql_event = flash[:pql_event] == "true"
    puts "Trigger: #{@trigger_pql_event}"
  end

  # GET /mask_requests/new
  def new
    redirect_to low_credits_path and return unless @canva.user.afford_generation?
    @mask_request = @canva.mask_requests.new
  end

  # GET /mask_requests/1/edit
  def edit
    @canva = @mask_request.canva
    if params[:manual].present?
      redirect_to low_credits_path and return unless @canva.user.afford_generation?
      # we don't need to update this, we can create a copy and work on that
      request = @mask_request.copy
      redirect_to edit_mask_request_path(request)
    elsif @mask_request.failed? || @mask_request.complete?
      redirect_to mask_request_path(@mask_request.id)
    end
  end



  # POST /mask_requests or /mask_requests.json
  def create
    @mask_request = @canva.mask_requests.new(mask_request_params)
    respond_to do |format|
      if @mask_request.save
        MaskValidatorJob.perform_now(@mask_request.id)
        @mask_request.reload
        if @mask_request.user_error.present?
          flash[:alert] = @mask_request.user_error
          @mask_request.destroy
          format.html { redirect_to new_canva_mask_request_path(@mask_request.canva),  status: :see_other }
        else
          current_user.mask_drawn!
          format.html { redirect_to edit_mask_request_path(@mask_request),  status: :see_other }
        end
      else
        format.html { render :new, status: :unprocessable_entity } and return
      end
    end
  end

  def update
    respond_to do |format|
      if @mask_request.preset.present? || @mask_request.update(preset_params)
        if MaskRequest.joins(canva: :user).where(users: { id: current_user.id }).count == 1
          flash[:pql_event] = "true"
        end
        current_user.style_selected!
        DesignGeneratorJob.perform_later(@mask_request.id)
        @mask_request.validating!
        format.html { redirect_to mask_request_path(@mask_request), status: :see_other }
        format.turbo_stream { redirect_to mask_request_path(@mask_request), status: :see_other }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end




  # POST /mask_requests or /mask_requests.json
  def destroy
    @mask_request.destroy!

    respond_to do |format|
      format.html { redirect_to mask_requests_path, notice: "Mask request was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def update_location
    user_params = location_params

    if user_params[:latitude].present? && user_params[:longitude].present?
       address = LocationService.reverse_geocode(user_params[:latitude], user_params[:longitude])
       user_params[:address] = address if address
    else
       user_params[:address] = nil
       user_params[:latitude] = nil
       user_params[:longitude] = nil
    end

    current_user.update(user_params)

    Turbo::StreamsChannel.broadcast_update_to(
      "canva_#{@canva.id}",
      target: "user_location_info",
      partial: "mask_requests/location_info",
      locals: { user: current_user }
    )
    head :ok
  end

  def generate_planting_guide
    @mask_request.fetching_plant_suggestions!
    PlantingGuideJob.perform_later(@mask_request.id)

    respond_to do |format|
      format.turbo_stream
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_mask_request
      @mask_request = MaskRequest.includes(mask_request_plants: :plant, canva: :user).find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def mask_request_params
      params.expect(mask_request: [ :mask, :device_width, :error_msg, :progress, results: [], progess: 0 ])
    end

    def set_canva
      @canva = Canva.includes(:user).find(params[:canva_id])
    end

    def preset_params
      params.expect(mask_request: [ :preset ])
    end

    def location_params
      params.require(:user).permit(:latitude, :longitude, address: {})
    end

    def plant_params
      params.require(:plant).permit(:english_name)
    end
end
