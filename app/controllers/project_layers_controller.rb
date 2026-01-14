class ProjectLayersController < ApplicationController
  before_action :set_project
  before_action :set_design, only: [:create]
  before_action :set_project_layer, only: %i[show update]

  def show
    @project_layer.mark_as_viewed!
    @project_layer.design.update(current_project_layer: @project_layer)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_path(@project, design_id: @project_layer.design_id) }
    end
  end

  def create
    parent_layer = @design.project_layers.find_by(id: params[:parent_layer_id]) || @design.project_layers.roots.first

    variations_count = (params[:variations].presence || 1).to_i.clamp(1, 4)
    created_layers = []

    ActiveRecord::Base.transaction do
      variations_count.times do |i|
        # Use explicit generation_type from frontend, fallback to style_preset logic as safety
        generation_type = params[:generation_type].presence || :style_preset

        layer = @design.project_layers.build(
          project: @project,
          parent: parent_layer,
          layer_type: "generated",
          generation_type: generation_type,
          auto_fix_id: params[:auto_fix_id],
          prompt: params[:prompt],
          preset: params[:preset],
          ai_assist: params[:ai_assist] == "true",
          progress: :preparing
        )

        if layer.save
          if params[:mask_data].present?
             decoded_data = Base64.decode64(params[:mask_data].split(',')[1])
             layer.mask.attach(
               io: StringIO.new(decoded_data),
               filename: "mask.png",
               content_type: 'image/png'
             )
          end

          created_layers << layer
          ProjectGenerationJob.perform_later(layer.id)
        else
          # Collect error from first failing layer and return
          error_message = layer.errors.full_messages.to_sentence
          flash.now[:alert] = error_message

          respond_to do |format|
            format.turbo_stream {
              render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
            }
            format.html { redirect_to project_path(@project, design_id: @design.id), alert: error_message }
          end
          raise ActiveRecord::Rollback
        end
      end

      # Mark AutoFix as applied if provided
      if params[:auto_fix_id].present?
        auto_fix = AutoFix.find_by(id: params[:auto_fix_id])
        auto_fix&.applied!
      end
    end

    # Guard against double render if validation failed inside transaction
    return if performed?

    # Force active layer to remain on parent (to prevent jumping to new incomplete layer)
    @design.update(current_project_layer: parent_layer) if parent_layer

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to project_path(@project, design_id: @design.id), notice: "#{variations_count} variations starting." }
    end
  rescue StandardError => e
    Rails.logger.error("Layer Create Error: #{e.message}")
    render status: :unprocessable_entity
  end

  def update
    if @project_layer.update(project_layer_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@project_layer) }
        format.html { redirect_to project_path(@project, design_id: @project_layer.design_id) }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_content }
        format.html { render :show, status: :unprocessable_content }
      end
    end
  end

  private

  def set_project
    # Handle both nested and flat if necessary, but routes are nested
    if params[:project_id]
      @project = current_user.projects.find(params[:project_id])
    elsif @project_layer
      @project = @project_layer.project
    end
  end

  def set_design
    @design = @project.designs.find(params[:design_id])
  end

  def set_project_layer
    @project_layer = ProjectLayer.find(params[:id])
  end

  def project_layer_params
    params.require(:project_layer).permit(:prompt, :preset, :transformation_type)
  end
end
