class MaskRequestsController < ApplicationController
  before_action :set_mask_request, only: %i[ show edit update destroy ]
  before_action :set_canva, only: %i[new create]
  skip_before_action :authenticate_user!, only: :explore

  # GET /mask_requests or /mask_requests.json
  def index
    @mask_requests = MaskRequest.complete.joins(canva: :user).where(users: { id: current_user.id })
  end

  def explore
    # canva_ids = Canva.joins(:user).where(user: { admin: true }).select(:id)
    @mask_requests = MaskRequest.complete.everyone.order(id: :desc).limit(40)
  end

  # GET /mask_requests/1 or /mask_requests/1.json
  def show
  end

  # GET /mask_requests/new
  def new
    redirect_to low_credits_path and return unless @canva.user.afford_generation?
    @mask_request = @canva.mask_requests.new
  end

  # GET /mask_requests/1/edit
  def edit
    # binding.irb
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
          format.html { redirect_to edit_mask_request_path(@mask_request),  status: :see_other }
        end
      else
        format.html { render :new, status: :unprocessable_entity } and return
      end
    end
  end

  # PATCH/PUT /mask_requests/1 or /mask_requests/1.json
  def update
    respond_to do |format|
      if @mask_request.update(preset_params)
        DesignGeneratorJob.perform_later(@mask_request.id)
        format.html { head :no_content }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /mask_requests/1 or /mask_requests/1.json
  def destroy
    @mask_request.destroy!

    respond_to do |format|
      format.html { redirect_to mask_requests_path, notice: "Mask request was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_mask_request
      @mask_request = MaskRequest.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def mask_request_params
      params.expect(mask_request: [ :mask, :device_width, :error_msg, :progress, results: [], progess: 0 ])
    end

    def set_canva
      @canva = Canva.find(params[:canva_id])
    end

    def preset_params
      params.expect(mask_request: [ :preset ])
    end
end
