class MaskRequestsController < ApplicationController
  before_action :set_mask_request, only: %i[ show edit update destroy ]
  before_action :set_canva, only: %i[new index create]

  # GET /mask_requests or /mask_requests.json
  def index
    @mask_requests = MaskRequest.all
  end

  # GET /mask_requests/1 or /mask_requests/1.json
  def show
  end

  # GET /mask_requests/new
  def new
    @mask_request = @canva.mask_requests.new
  end

  # GET /mask_requests/1/edit
  def edit
    @canva = @mask_request.canva
    if @mask_request.preset.present? && @mask_request.main_view.attached?
      # we don't need to update this, we can create a copy and work on that
      request = @mask_request.copy
      redirect_to edit_mask_request_path(request) if request.persisted?
    end
  end

  # POST /mask_requests or /mask_requests.json
  def create
    @mask_request = @canva.mask_requests.new(mask_request_params)

    respond_to do |format|
      if @mask_request.save
        @mask_request.validate_mask
        if @mask_request.reload.validated?
          format.html { redirect_to edit_mask_request_path(@mask_request), notice: "Select presets" }
        else
        format.html { redirect_to @mask_request, notice: "Mask request was successfully created." }
        format.json { render :show, status: :created, location: @mask_request }
        end
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @mask_request.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /mask_requests/1 or /mask_requests/1.json
  def update
    respond_to do |format|
      if @mask_request.update(preset_params)
        format.html { redirect_to @mask_request, notice: "Mask request was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @mask_request }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @mask_request.errors, status: :unprocessable_entity }
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
      params.expect(mask_request: [ :mask, :original_image, :device_width, :error_msg, :progress, results: [] ])
    end

    def set_canva
      @canva = Canva.find(params[:canva_id])
    end

    def preset_params
      params.expect(mask_request: [ :preset ])
    end
end
