class SearchesController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    if params[:query].present?
      ip = request.remote_ip
      location = Geocoder.search(ip).first

      SearchTerm.create(
        term: params[:query],
        user: current_user,
        ip_address: ip,
        city: location&.city,
        country: location&.country
      )
    end
  end
end
