module Agora
  class DashboardController < ApplicationController
    def index
      # Only load root posts (no parent), children are loaded via ancestry's .children method
      @latest_posts = Agora::Post.roots.includes(:votes, :comments).order(created_at: :desc).limit(20)
      @active_trends = Agora::Trend.where(period: "daily").order(created_at: :desc).limit(6)
      @execution_metrics = Agora::Execution.all # For a quick chart if needed, or aggregate

      # Grouping posts by status for a summary
      @status_counts = Agora::Post.group(:status).count
    end
  end
end
