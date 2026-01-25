class DesignsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project

  def create
    if params[:project_layer_id].present?
      source_layer = @project.project_layers.find(params[:project_layer_id])

      title_source = source_layer.generation_type&.humanize || "Layer"
      @design = @project.designs.create!(title: "Design from #{title_source}")

      layer = @design.project_layers.new(
          project: @project,
          layer_type: :original,
          progress: :complete
      )

      source_image_attachment = source_layer.display_image
      if source_image_attachment&.attached?
        layer.image.attach(source_image_attachment.blob)
      end

      if layer.save
         @project.update(current_design: @design)
         redirect_to project_path(@project, design_id: @design.id), notice: "New design created from layer!"
      else
         redirect_to project_path(@project), alert: "Failed to create design."
      end
      return
    end

    image = params[:image]

    if image.blank?
      redirect_to project_path(@project), alert: "No image provided"
      return
    end

    # Create the design (using filename as title, or a default)
    # The default title callbacks in Design model might handle blanks, but we want a useful title if possible.
    design_title = image.original_filename.split(".").first.titleize

    @design = @project.designs.create!(title: design_title)

    # Create the initial layer
    layer = @design.project_layers.new(
      project: @project,
      layer_type: :original,
      image: image,
      progress: :complete
    )

    if layer.save
      SketchAnalysisJob.perform_later(layer)
      @project.update(current_design: @design)

      redirect_to project_path(@project, design_id: @design.id), notice: "New design created!"
    else
      render :new, alert: "Failed to create design: #{layer.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
  end
end
