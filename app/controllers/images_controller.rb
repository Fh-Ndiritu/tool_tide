class ImagesController < ApplicationController
  def index
    # we shall add more conversions later
    @conversion = "text"
  end

  def create
    result = ImageOrchestratorService.perform(image_params[:conversion], image_params[:images])
  end

  private

  def image_params
    params.permit(:conversion, images: [])
  end
end
