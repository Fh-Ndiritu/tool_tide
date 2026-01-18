module Admin
  class ProjectsController < BaseController
    def index
      @projects = Project.joins(designs: :project_layers)
                         .merge(ProjectLayer.generated)
                         .distinct
                         .includes(:user)
                         .order(created_at: :desc)
    end

    def show
      @project = Project.includes(designs: :project_layers).find(params[:id])
    end
  end
end
