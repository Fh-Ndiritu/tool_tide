# app/controllers/event_tags_controller.rb

class EventTagsController < ApplicationController
  # caches_action :show, expires_in: 1.day, if: -> { Rails.env.production? }

  def show
    @event_tag = Tag.find_by_slug!(params[:slug])

    @mask_requests = MaskRequest.joins(:generation_taggings).limit(4)
    @text_requests = TextRequest.joins(:generation_taggings).limit(4)
  end
end
