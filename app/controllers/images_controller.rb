class ImagesController < ApplicationController
  def index
    # we shall add more conversions later
    @conversion = params[:conversion] || "text"
  end

  def create
    result = ImageOrchestratorService.perform(image_params[:conversion], image_params[:images])
    if result.success?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("results", partial: "results_#{image_params[:conversion]}", locals: { pages:  result.data }) +
          turbo_stream.replace("image_form", partial: "image_form", locals: { conversion: image_params[:conversion] })
        end
        format.html { redirect_to root_path }
      end
    else
      flash[:error] = result.error
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("flash", partial: "/shared/flash")
        end
        format.html { redirect_to root_path }
      end
    end
  end

  private

  def image_params
    params.permit(:conversion, images: [])
  end
end
