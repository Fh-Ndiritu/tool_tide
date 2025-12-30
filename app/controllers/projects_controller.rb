class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [ :show, :update ]

  def index
    @projects = current_user.projects.active.order(updated_at: :desc)
    @new_project = Project.new
  end

  def create
    @project = current_user.projects.build(title: "Untitled Project #{Date.today}")

    if @project.save
      redirect_to project_path(@project)
    else
      redirect_to projects_path, alert: "Failed to create project."
    end
  end

  def show
    @layers = @project.layers.includes(image_attachment: :blob).order(created_at: :asc)
    @initial_layer = @layers.find { |l| l.layer_type_original? }
  end

  def update
    if @project.update(project_params)
      head :ok
    else
      render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = current_user.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:title, :status)
  end
end
