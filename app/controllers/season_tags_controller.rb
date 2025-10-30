# frozen_string_literal: true

class SeasonTagsController < ApplicationController
  skip_before_action :authenticate_user!
  def show
  @tag = Tag.find_by(slug: params[:slug])
      if @tag.blank?
        head :gone
        return
      end
    @mask_requests = MaskRequest.joins(:generation_taggings).where(generation_taggings: { tag: @tag }).limit(10)
    @text_requests = TextRequest.joins(:generation_taggings).where(generation_taggings: { tag: @tag }).limit(10)

    render "event_tags/show"
  end
end
