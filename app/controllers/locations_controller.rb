class LocationsController < ApplicationController
  skip_before_action :authenticate_user!
  def show
    # @location = Location.find_by(slug: params[:slug])

    # if @location.blank?
      head :gone
      return
    # end

   @mask_requests = MaskRequest.unscoped
    .complete
    .left_outer_joins(:generation_taggings)
    .where(generation_taggings: { tag_id: nil })
    .joins(canva: :user)
    .where(users: { admin: true })
    .references(canva: :user)
    .order("RANDOM()")
    .limit(4)

  # This finds all TextRequests that DO NOT have a matching record in generation_taggings
  @text_requests = TextRequest.complete
    .left_outer_joins(:generation_taggings)
    .where(generation_taggings: { tag_id: nil })
    .joins(:user)
    .where(users: { admin: true })
    .references(:user)
    .order("RANDOM()")
    .limit(6)
  end
end
