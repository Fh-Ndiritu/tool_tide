module Agora
  class TrendsController < ApplicationController
    def index
      @trends = Agora::Trend.where(period: "daily").order(created_at: :desc).limit(50)
      @weekly_trends = Agora::Trend.where(period: "weekly").order(created_at: :desc).limit(5)
    end
  end
end
