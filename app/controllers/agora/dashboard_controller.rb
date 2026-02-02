module Agora
  class DashboardController < ApplicationController
    def index
      # Only load root posts (no parent), children are loaded via ancestry's .children method
      scope = Agora::Post.roots.includes(:votes, :comments).order(created_at: :desc)

      if params[:time_filter] == "24h"
         scope = scope.last_24_hours
      end

      if params[:status_filter].present?
        # Map filter names to actual statuses
        # 'accepted' includes both accepted and proceeding (valid outcomes)
        statuses = case params[:status_filter]
        when "accepted"
                     %w[accepted proceeding]
        else
                     params[:status_filter]
        end
        scope = scope.by_final_status(statuses)
      end

      # Use :offset pagination for v43
      @pagy, @latest_posts = pagy(:offset, scope, limit: 6)
      @active_trends = Agora::Trend.where(period: "daily").order(created_at: :desc).limit(6)
      @execution_metrics = Agora::Execution.all # For a quick chart if needed, or aggregate

      # Grouping posts by status for a summary
      @status_counts = Agora::Post.group(:status).count
    end
  end
end
