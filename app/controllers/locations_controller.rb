class LocationsController < ApplicationController
  skip_before_action :authenticate_user!
  def show
    @location = Location.find_by_slug(params[:slug])
    @mask_requests = MaskRequest.unscoped
    .complete
    .joins(canva: :user)
    .where(users: { admin: true })
    .references(canva: :user)
    .order("RANDOM()")
    .limit(4)

    @text_requests = TextRequest.complete
    .joins(:user)
    .where(users: { admin: true })
    .references(:user)
    .order("RANDOM()")
    .limit(4)
  end
end
