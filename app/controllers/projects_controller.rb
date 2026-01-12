class ProjectsController < ApplicationController
  before_action :set_project, only: :show

  def index
    @projects = current_user.projects.order(created_at: :desc)
    @new_project = Project.new
  end

  def show
    @project = current_user.projects.find(params[:id])

    if params[:design_id]
      @active_design = @project.designs.find(params[:design_id])
      @project.update(current_design: @active_design)
    elsif @project.current_design
      @active_design = @project.current_design
    else
      @active_design = @project.designs.order(created_at: :desc).first
      @project.update(current_design: @active_design) if @active_design
    end

    # Fallback if no design exists (shouldn't happen with valid project creation)
    unless @active_design
      # Try one last time to find ANY design if for some reason the above failed silently
      @active_design = @project.designs.last
      if @active_design
         @project.update(current_design: @active_design)
      else
         redirect_to projects_path, alert: "Project has no designs."
         return
      end
    end

    render layout: "application"
  end



  def update
    @project = current_user.projects.find(params[:id])
    if @project.update(project_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @project, notice: "Project updated." }
      end
    else
      render :show, status: :unprocessable_entity
    end
  end

  def create
    @project = current_user.projects.create(title: "Untitled Project")
    @design = @project.designs.create(title: params[:image].original_filename)

    @layer = @design.project_layers.create(
      project: @project,
      layer_type: :original,
      progress: :complete
    )

    @layer.image.attach(params[:image])

    redirect_to project_path(@project)
  rescue StandardError => e
    redirect_to projects_path, alert: "Failed to create project: #{e.message}"
  end

  private

  def set_project
    @project = current_user.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:title, :current_design_id) # Allow title and current_design_id
  end
end
