class ProjectLayersController < ApplicationController
  before_action :set_project
  before_action :set_design, only: [:create]
  before_action :set_project_layer, only: %i[show update]

  def show
  end

  def create
    parent_layer = @design.project_layers.find_by(id: params[:parent_layer_id]) || @design.project_layers.roots.first

    variations_count = (params[:variations].presence || 1).to_i.clamp(1, 4)
    created_layers = []

    ActiveRecord::Base.transaction do
      variations_count.times do |i|
        layer = @design.project_layers.build(
          project: @project,
          parent: parent_layer,
          layer_type: "generated",
          prompt: params[:prompt],
          preset: params[:preset],
          ai_assist: params[:ai_assist] == "true",
          progress: :preparing
        )

        layer.save!

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
      end
    end

    respond_to do |format|
      format.turbo_stream {
         render turbo_stream: created_layers.map { |l|
           turbo_stream.append("layers_list", partial: "project_layers/project_layer", locals: { project_layer: l })
         }
      }
      format.html { redirect_to project_path(@project, design_id: @design.id), notice: "#{variations_count} variations starting." }
    end
  rescue StandardError => e
    Rails.logger.error("Layer Create Error: #{e.message}")
    render status: :unprocessable_entity
  end

  def update
    if @project_layer.update(project_layer_params)
      render turbo_stream: turbo_stream.replace(@project_layer)
    else
      render status: :unprocessable_entity
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
