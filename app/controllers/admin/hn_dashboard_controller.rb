module Admin
  class HnDashboardController < BaseController
    def show
      # 1. Historical Data

      # A. Average for this Day of Week (excluding today)
      # 1. Historical Data

      # A. Average for this Day of Week (excluding today)
      @averages_day_of_week = HnActivitySnapshot.where(day_of_week: Time.current.wday)
                                    .where("created_at < ?", Time.current.beginning_of_day)
                                    .group(:time_bucket)
                                    .average(:items_count)
                                    .transform_values(&:to_f)
                                    .sort.to_h

      # B. Average for this Time of Day (All days, excluding today)
      @averages_time_of_day = HnActivitySnapshot.where("created_at < ?", Time.current.beginning_of_day)
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
        @current_avg = @averages_day_of_week[@last_snapshot.time_bucket] || 0

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
