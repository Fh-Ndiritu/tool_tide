# frozen_string_literal: true

class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]
  rate_limit to: 3, within: 1.minute, by: -> { request.ip }, name: "shortterm_home_index"
  rate_limit to: 5, within: 20.minutes, by: -> { request.ip }, name: "longterm_home_index"

  def index
    @mask_requests = MaskRequest.complete.everyone.order(id: :desc).limit(12)
  end

  def credits
    @conversion_event = flash[:conversion_event]
  end
end
