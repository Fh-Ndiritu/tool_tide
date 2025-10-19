# app/controllers/event_tags_controller.rb

class EventTagsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @tag = Tag.find_by_slug!(params[:slug])
    @mask_requests = MaskRequest.joins(:generation_taggings).where(generation_taggings: { tag: @tag }, trial_generation: true).limit(10)
    @text_requests = TextRequest.joins(:generation_taggings, :user).where(generation_taggings: { tag: @tag }, user: { admin: true }).limit(10)

    if @text_requests.blank?
      @text_requests = TextRequest.complete
    .left_outer_joins(:generation_taggings)
    .where(generation_taggings: { tag_id: nil })
    .joins(:user)
    .where(users: { admin: true })
    .references(:user)
    .order("RANDOM()")
    .limit(10)
    end
  end
end
