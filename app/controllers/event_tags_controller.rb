# app/controllers/event_tags_controller.rb

class EventTagsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @tag = Tag.find_by_slug!(params[:slug])
    @mask_requests = MaskRequest.joins(:generation_taggings).where(generation_taggings: { tag: @tag })
    @text_requests = TextRequest.joins(:generation_taggings).where(generation_taggings: { tag: @tag })
  end
end
