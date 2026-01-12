class DesignsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project

  def create
    image = params[:image]

    if image.blank?
      redirect_to project_path(@project), alert: "No image provided"
      return
    end

    # Create the design (using filename as title, or a default)
    # The default title callbacks in Design model might handle blanks, but we want a useful title if possible.
    design_title = image.original_filename.split('.').first.titleize

    @design = @project.designs.create!(title: design_title)

    # Create the initial layer
    @design.project_layers.create!(
      project: @project,
      layer_type: :original,
      image: image,
      progress: :complete
    )

    @project.update(current_design: @design)

    redirect_to project_path(@project, design_id: @design.id), notice: "New design created!"
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
  end
end
