class CanvasController < AppController
  before_action :set_canva, only: %i[ show update destroy ]

  # GET /canvas/new
  def new
    redirect_to onboarding_survey_path if !current_user.can_skip_onboarding_survey?
    @canva = Canva.new
  end

  # POST /canvas or /canvas.json
  def create
    @canva = Canva.new(canva_params)

    respond_to do |format|
      if @canva.save
        result = SketchAnalysisJob.perform_now(@canva)
        redirect_path = new_canva_mask_request_path(@canva, sketch_detected: (result == "sketch"))
        format.html { redirect_to redirect_path, status: :see_other }
        format.turbo_stream { redirect_to redirect_path, status: :see_other }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
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
      params.expect(canva: [ :user_id, :image, :device_width, :treat_as ]).merge(user: current_user)
    end
end
