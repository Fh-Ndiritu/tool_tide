class TextRequestsController < ApplicationController
  before_action :set_text_request, only: %i[ show update ]
  before_action :authorize_user, only: %i[ update destroy ]

  # GET /text_requests or /text_requests.json
  def index
    @text_requests = current_user.text_requests.complete_or_in_progress
    @current_request = current_user.text_requests.find_by(id: params[:current_request]) || @text_requests.first
    if @current_request.blank?
      if current_user.canvas.joins(:mask_requests).where(mask_requests: { progress: :complete }).present?
      redirect_to mask_requests_path, notice: "Use pen button to start text editing" and return
      else
      redirect_to new_canva_path, alert: "Create a brush landscape to start text editing"  and return
      end
    end
  end

  # GET /text_requests/1 or /text_requests/1.json
  def show
  end

  # GET /text_requests/new
  def new
     redirect_to low_credits_path and return unless current_user.afford_text_editing?

    blob = ActiveStorage::Blob.find_signed(params[:signed_blob_id])
    redirect_to canvas_path, alert: "Image was not found!" and return if blob.blank?
    @text_request = current_user.text_requests.new.tap do |request|
      request.original_image.attach(blob)
      request.save!
    end
    redirect_to text_requests_path(current_request: @text_request.id)
  end


  # PATCH/PUT /text_requests/1 or /text_requests/1.json
  def update
     # if we get an update request for a text_request which already has a result image
     redirect_to low_credits_path and return unless current_user.afford_text_editing?

    if @text_request.result_image.attached? && text_request_params[:prompt].present?
      child = @text_request.children.new(text_request_params.merge(user: current_user))
      .tap do |request|
        request.original_image.attach(@text_request.result_image.blob)
        request.save
      end

      redirect_to text_requests_path(current_request: child.id)
    elsif @text_request.update(text_request_params)
        redirect_to text_requests_path(current_request: @text_request.id)
    else
      respond_to do |format|
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /text_requests/1 or /text_requests/1.json
  def destroy
    @text_request.destroy!

    respond_to do |format|
      format.html { redirect_to text_requests_path, notice: "Text request was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

    def authorize_user
      return if current_user == @text_request.user

      redirect_to new_canva_path, notice: "You don't have access to modify" and return
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_text_request
      @text_request = TextRequest.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def text_request_params
      params.expect(text_request: [ :original_image, :prompt, :progress, :user_error, :visibility, :trial_generation, :user_id, :ancestry ])
    end
end
