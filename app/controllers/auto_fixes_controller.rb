class AutoFixesController < ApplicationController
  before_action :set_project_layer

  def create
    # Clear existing pending fixes for this layer
    @project_layer.auto_fixes.pending.destroy_all

    # Enqueue background job
    AutoFixDetectionJob.perform_later(@project_layer.id)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back(fallback_location: project_path(@project_layer.project), notice: "Analysis started.") }
    end
  end

  private

  def set_project_layer
    @project_layer = ProjectLayer.find(params[:project_layer_id])
  end
end
