class SketchRequestsController < ApplicationController
  before_action :set_canva, only: %i[create]
  before_action :set_sketch_request, only: %i[show new_mask_request]

  def create
    service = SketchPipelineService.new(@canva)
    if (sketch_request = service.start_generation)
      redirect_to sketch_request_path(sketch_request), notice: "Sketch pipeline started!"
    else
      redirect_to @canva, alert: "Failed to start generation. Please try again."
    end
  end

  def show
    # @sketch_request is set
  end


  def new_mask_request
    # Create or find a Canva from the result
    canva = @sketch_request.create_result_canva!
    # Redirect to the drawing interface (new mask request on that canva)
    redirect_to new_canva_mask_request_path(canva, sketch_detected: false), notice: "Project created from result! Please outline the area to modify."
  end

  private

  def set_canva
    @canva = Canva.find(params[:canva_id])
  end

  def set_sketch_request
    @sketch_request = SketchRequest.with_attached_rotated_view.includes(:canva).find(params[:id])
  end
end
