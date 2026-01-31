module Agora
  class ExecutionMetricSchema < RubyLLM::Schema
    object :metrics do
      number :spend, description: "Total amount spent (currency value)"
      integer :impressions, description: "Total number of impressions"
      integer :clicks, description: "Total number of clicks"
      number :roas, description: "Return on Ad Spend (ROAS) value (e.g. 2.5)"
    end
  end

  class AnalyticsExtractor
    def self.perform(execution)
      new(execution).extract
    end

    def initialize(execution)
      @execution = execution
    end

    def extract
      return unless @execution.analytics_screenshot.attached?

      prompt = "Analyze this analytics dashboard screenshot. Extract the visible key metrics (Spend, Impressions, Clicks, ROAS). If a metric is not visible, return null or 0."

      # Validates attached image via ActiveStorage
      response = CustomRubyLLM.context.chat.with_schema(ExecutionMetricSchema).ask(
        prompt,
        with: @execution.analytics_screenshot
      )

      data = response.content["metrics"]

      if data
        @execution.update!(
          spend: data["spend"],
          impressions: data["impressions"],
          clicks: data["clicks"],
          roas: data["roas"]
        )
      end

      data
    rescue StandardError => e
      Rails.logger.error("Agora::AnalyticsExtractor Failed: #{e.message}")
      nil
    end
  end
end
