class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [ :show, :update, :suggest_plants, :update_location ]

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

  def update_location
    if current_user.update(latitude: params[:latitude], longitude: params[:longitude])
      head :ok
    else
      head :unprocessable_entity
    end
  end

  def suggest_plants
    # Mocking AI response as we don't have the full integration yet
    # In a real scenario, this would trigger a job or service object
    @plants = [
      Plant.new(english_name: "Purple Coneflower", description: "Echinacea purpurea is a North American species of flowering plant in the sunflower family.", size: 3),
      Plant.new(english_name: "Black-eyed Susan", description: "Rudbeckia hirta is a North American flowering plant in the family Asteraceae.", size: 2),
      Plant.new(english_name: "Hostas", description: "Hosta is a genus of plants commonly known as hostas, plantain lilies and occasionally by the Japanese name giboshi.", size: 1)
    ]

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("plant_results", partial: "projects/plant_list", locals: { plants: @plants })
      end
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
