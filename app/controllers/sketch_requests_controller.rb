class SketchRequestsController < ApplicationController
  before_action :set_canva, only: %i[create]
  before_action :set_sketch_request, only: %i[show new_mask_request]

  def create
    service = SketchPipelineService.new(@canva)
    if (sketch_request = service.start_generation)
      redirect_to sketch_request_path(sketch_request), notice: "Sketch pipeline started!"
    else
      redirect_to @canva.mask_requests.last || @canva, alert: "Failed to start generation (Insufficient credits?)"
    end
  end

  def show
    # @sketch_request is set
  end

  def new_mask_request
    # Create a NEW Canva from the result
    mask_request = @sketch_request.create_mask_request!

    redirect_to edit_mask_request_path(mask_request), notice: "New project created from result!"
  end

  private

  def set_canva
    @canva = Canva.find(params[:canva_id])
  end

  def set_sketch_request
    @sketch_request = SketchRequest.find(params[:id])
  end
end
