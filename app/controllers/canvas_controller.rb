class CanvasController < ApplicationController
  before_action :set_canva, only: %i[ show edit update destroy ]
  before_action :issue_daily_credits, only: :new

  # GET /canvas or /canvas.json
  def index
    @canvas = current_user.canvas.joins(:mask_requests).where(mask_requests: { progress: :complete }).includes(:mask_requests).order(created_at: :desc)
  end

  # GET /canvas/1 or /canvas/1.json
  def show
  end

  # GET /canvas/new
  def new
    @canva = Canva.new
  end

  # GET /canvas/1/edit
  def edit
  end

  # POST /canvas or /canvas.json
  def create
    @canva = Canva.new(canva_params)

    respond_to do |format|
      if @canva.save
        format.html { redirect_to new_canva_mask_request_path(@canva), status: :see_other }
        format.json { render :show, status: :created, location: @canva }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @canva.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /canvas/1 or /canvas/1.json
  def update
    respond_to do |format|
      if @canva.update(canva_params)
        format.html { redirect_to new_canva_mask_request_path(@canva), status: :see_other }
        format.json { render :show, status: :ok, location: @canva }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @canva.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /canvas/1 or /canvas/1.json
  def destroy
    @canva.destroy!

    respond_to do |format|
      format.html { redirect_to canvas_path, notice: "Canva was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_canva
      @canva = Canva.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def canva_params
      params.expect(canva: [ :user_id, :image, :device_width ]).merge(user: current_user)
    end

    def issue_daily_credits
      current_user.issue_daily_credits unless current_user.received_daily_credits?
    end
end
