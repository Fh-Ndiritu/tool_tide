class TextRequestsController < ApplicationController
  before_action :set_text_request, only: %i[ show edit update destroy ]

  # GET /text_requests or /text_requests.json
  def index
    @text_requests = TextRequest.all
  end

  # GET /text_requests/1 or /text_requests/1.json
  def show
  end

  # GET /text_requests/new
  def new
    blob = ActiveStorage::Blob.find_signed(params[:signed_blob_id])
    redirect_to canvas_path, alert: "Image was not found!" and return if blob.blank?
    @text_request = current_user.text_requests.new.tap do |request|
      request.original_image.attach(blob)
      request.save!
    end
    redirect_to edit_text_request_path(@text_request)
  end

  # GET /text_requests/1/edit
  def edit
  end

  # POST /text_requests or /text_requests.json
  def create
    @text_request = TextRequest.new(text_request_params)

    respond_to do |format|
      if @text_request.save
        format.html { redirect_to @text_request, notice: "Text request was successfully created." }
        format.json { render :show, status: :created, location: @text_request }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @text_request.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /text_requests/1 or /text_requests/1.json
  def update
    # if we get an update request for a text_request which already has a result image
    # we fork it and make edits on new instance
    respond_to do |format|
      if @text_request.update(text_request_params)
        format.html { redirect_to @text_request, notice: "Text request was successfully updated.", status: :see_other }
        format.turbo_stream { head :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
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
    # Use callbacks to share common setup or constraints between actions.
    def set_text_request
      @text_request = TextRequest.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def text_request_params
      params.expect(text_request: [ :original_image, :prompt, :progress, :user_error, :visibility, :trial_generation, :user_id, :ancestry ])
    end
end
