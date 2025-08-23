class LandscapeRequestsController < ApplicationController
  before_action :set_landscape_request, only: :location

  def location
    if location_params.present?
      results = Geocoder.search([ location_params[:latitude], location_params[:longitude] ])
      current_user.update!(location_params)

      current_user.update! address: results.first&.data.dig('address') if results.present?
      @landscape_request.toggle!(:use_location)
    end
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(:local_location, partial: '/landscapes/location', locals: { landscape_request: @landscape_request, current_user: })
      end
    end
  end

  private

  def location_params
    params.permit(:latitude, :longitude).compact_blank.transform_values { |v| v.to_d }
  end

  def set_landscape_request
    @landscape_request = LandscapeRequest.find(params[:id])
  end
end
