# frozen_string_literal: true

class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]

  def index
    @mask_requests = MaskRequest.complete.everyone.order(id: :desc).limit(4)
    tags = Tag.where(title: [ "Christmas", "Halloween", "Winter" ])
    text_requests = TextRequest.joins(:generation_taggings, :user).where(user: { admin: true })

    @text_requests = tags.map { |tag| text_requests.where(generation_taggings: { tag: tag }).limit(4) }.flatten
  end

  def credits; end
end
