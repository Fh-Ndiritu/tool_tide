class TextEditorsController < ApplicationController
  before_action :set_text_editor, only: %i[ show edit update destroy ]

  # GET /text_editors or /text_editors.json
  def index
    @text_editors = TextEditor.all
  end

  # GET /text_editors/1 or /text_editors/1.json
  def show
  end

  # GET /text_editors/new
  def new
    @text_editor = TextEditor.new(user: current_user)
    if params[:blob_id]
      blob = ActiveStorage::Blob.find_signed!(params[:blob_id])
      @text_editor.original_image.attach(blob)
      @text_editor.save!
      redirect_to edit_text_editor_path(@text_editor) and return
    end
  end

  # GET /text_editors/1/edit
  def edit
  end

  # POST /text_editors or /text_editors.json
  def create
    @text_editor = TextEditor.new(text_editor_params)

    respond_to do |format|
      if @text_editor.save
        format.html { redirect_to @text_editor, notice: "Text editor was successfully created." }
        format.json { render :show, status: :created, location: @text_editor }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @text_editor.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /text_editors/1 or /text_editors/1.json
  def update
    respond_to do |format|
      if @text_editor.update(text_editor_params)
        format.html { redirect_to @text_editor, notice: "Text editor was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @text_editor }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @text_editor.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /text_editors/1 or /text_editors/1.json
  def destroy
    @text_editor.destroy!

    respond_to do |format|
      format.html { redirect_to text_editors_path, notice: "Text editor was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_text_editor
      @text_editor = TextEditor.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def text_editor_params
      params.expect(text_editor: [ :user_id, :original_image, :result_image, :prompt ])
    end
end
