class Admin::LandscapesController < ApplicationController
  def index
    redirect_to root_path unless params[:user].present? && params[:user] == "shark@fh"
    if params[:day].present?
      @landscapes = Landscape.where(created_at: params[:day].to_i.days.ago.beginning_of_day..params[:day].to_i.days.ago.end_of_day)
    else
      @landscapes = Landscape.all
    end
  end
end
