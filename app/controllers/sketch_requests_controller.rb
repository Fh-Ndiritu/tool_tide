class SketchRequestsController < ApplicationController
  before_action :set_canva, only: %i[create]
  before_action :set_sketch_request, only: %i[show new_mask_request]

  def create
    service = SketchPipelineService.new(@canva)
    if (sketch_request = service.start_generation)
      redirect_to sketch_request_path(sketch_request), notice: "Sketch pipeline started!"
    else
      redirect_to @canva.mask_request, alert: "Failed to start generation (Insufficient credits?)"
    end
  end

  def show
    # @sketch_request is set
  end

  def new_mask_request
    # Create a NEW Canva from the result (photorealistic view usually)
    # The user wants "New Canva where mask_request mode is preselected"

    source_image = @sketch_request.photo_view || @sketch_request.canva.image

    # We need to duplicate the blob to a new Canva
    new_canva = Canva.create!(user: current_user)

    new_canva.image.attach(source_image.blob)

    # Pre-select mask request mode?
    # Usually usage is creating a mask request on the new canva.
    # We can redirect to the mask_request#show (which likely handles the 'new' state logic if we set it up right, or we manually create a mask request)

    redirect_to new_canva_mask_request_path(new_canva), notice: "New project created from result!"
  end

  private

  def set_canva
    @canva = Canva.find(params[:canva_id])
  end

  def set_sketch_request
    @sketch_request = SketchRequest.find(params[:id])
  end
end
