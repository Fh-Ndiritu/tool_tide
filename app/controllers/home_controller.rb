# frozen_string_literal: true

class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]

  def index
    @mask_requests = MaskRequest.complete.everyone.order(id: :desc).limit(12)
  end

  def credits
    @conversion_event = flash[:conversion_event]
  end
end
