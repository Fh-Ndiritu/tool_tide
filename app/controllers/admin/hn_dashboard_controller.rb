module Admin
  class HnDashboardController < BaseController
    def show
      # 1. Historical Data (Average per time bucket for current day)
      # We want a line chart of averages for today's day_of_week
      day = Time.current.wday

      # Group by time_bucket, calculate average items_count
      # Result: { 0 => 12.5, 30 => 14.0, ... 2330 => ... }
      @averages = HnActivitySnapshot.where(day_of_week: day)
                                    .group(:time_bucket)
                                    .average(:items_count)
                                    .transform_values(&:to_f)
                                    .sort.to_h

      # 2. Today's Actual Data
      # We want to overlay today's actual snapshots
      # Get snapshots for today (since midnight)
      # Note: We need to define "today" correctly regarding timezones.
      # Assuming app timezone is set.
      start_of_day = Time.current.beginning_of_day
      @todays_snapshots = HnActivitySnapshot.where("created_at >= ?", start_of_day)
                                            .order(:time_bucket)
                                            .pluck(:time_bucket, :items_count)
                                            .to_h

      # 3. Stats for Cards
      @last_snapshot = HnActivitySnapshot.order(created_at: :desc).first
      if @last_snapshot
        @current_velocity = @last_snapshot.items_count
        @current_avg = @averages[@last_snapshot.time_bucket] || 0

        # Traffic Load: (Current / Avg) * 100
        if @current_avg.positive?
          @traffic_percentage = ((@current_velocity.to_f / @current_avg) * 100).round
        else
          @traffic_percentage = 0
        end

        # Calculate Next Update
        interval = Rails.env.development? ? 2.minutes : 30.minutes
        @next_update_at = @last_snapshot.created_at + interval
      else
        @current_velocity = "-"
        @current_avg = "-"
        @traffic_percentage = "-"
        @next_update_at = Time.current + (Rails.env.development? ? 2.minutes : 30.minutes)
      end
    end
  end
end
