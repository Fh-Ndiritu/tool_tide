module Agora
  class StatusHudComponent < ViewComponent::Base
    def initialize
      @status_counts = Agora::Post.group(:status).count
      @active_trends_count = Agora::Trend.where(period: "daily").count
    end

    def accepted_count
      @status_counts["accepted"] || 0
    end

    def proceeding_count
      @status_counts["proceeding"] || 0
    end

    def reviewing_count
      @status_counts["published"] || 0
    end

    def trends_count
      @active_trends_count
    end
  end
end
