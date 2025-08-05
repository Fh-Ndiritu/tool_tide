class Admin::LandscapesController < Admin::BaseController
  def index
    if params[:day].present?
      @landscapes = Landscape.where(created_at: params[:day].to_i.days.ago.beginning_of_day..params[:day].to_i.days.ago.end_of_day).order(created_at: :desc)
    else
      @landscapes = Landscape.all.order(created_at: :desc)
    end
  end
end
