module Agora
  class TrendsController < ApplicationController
    def index
      # Day-based pagination: page 0 = today, page 1 = yesterday, etc.
      @day_offset = params[:day].to_i
      @current_date = @day_offset.days.ago.to_date

      # Get trends for the selected day
      day_start = @current_date.beginning_of_day
      day_end = @current_date.end_of_day

      @trends = Agora::Trend.where(period: "daily")
                            .where(created_at: day_start..day_end)
                            .order(created_at: :desc)
      @weekly_trends = Agora::Trend.where(period: "weekly").order(created_at: :desc).limit(5)

      # Check if there are older trends for navigation
      @has_older = Agora::Trend.where("created_at < ?", day_start).exists?
      @has_newer = @day_offset > 0
    end
  end
end
