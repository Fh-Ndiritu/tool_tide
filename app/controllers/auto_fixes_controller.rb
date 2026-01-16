class AutoFixesController < ApplicationController
  before_action :set_project_layer

  def create
    # Clear existing pending fixes for this layer
    @project_layer.auto_fixes.pending.destroy_all

    # Perform detection synchronously to avoid WebSocket race condition
    begin
      AutoFixDetectorService.perform(@project_layer)
      @auto_fixes = @project_layer.auto_fixes.reload
      @success = true
    rescue StandardError => e
      Rails.logger.error("AutoFix detect
      ion failed: #{e.message}")
      @success = false
      @error_message = "Analysis failed. Please try again."
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back(fallback_location: project_path(@project_layer.project), notice: @success ? "Analysis complete." : @error_message) }
    end
  end

  private

  def set_project_layer
    @project_layer = ProjectLayer.find(params[:project_layer_id])
  end
end
