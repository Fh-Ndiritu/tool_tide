module Agora
  class TemporalAggregatorJob < ApplicationJob
    queue_as :default

    def perform
      # 1. Weekly Summarization
      # Find all daily trends from the last week that haven't been summarized
      week_trends = Agora::Trend.where(period: "daily")
                                .where("created_at >= ?", 1.week.ago)

      return if week_trends.empty?

      summary_content = summarize_week(week_trends)

      Agora::Trend.create!(
        period: "weekly",
        content: summary_content,
        source_metadata: { source: "aggregated", range: "1_week", count: week_trends.count }
      )

      # 2. Pruning / Archiving
      # Delete daily trends older than 30 days to keep DB light
      Agora::Trend.where(period: "daily")
                  .where("created_at < ?", 30.days.ago)
                  .delete_all
    end

    private

    def summarize_week(trends)
      trend_list = trends.map { |t| "- #{t.content['trend_name']}: #{t.content['viral_hook_idea']}" }.join("\n")

      prompt = <<~PROMPT
        You are the System Historian.

        TASK:
        Summarize the following list of daily trends from the past week into a "Weekly Meta-Trend" report.
        Identify the overarching theme.

        DAILY TRENDS:
        #{trend_list}

        OUTPUT (JSON):
        {
          "trend_name": "Weekly Meta-Trend: [Theme]",
          "signal_strength": [Average calculation],
          "viral_hook_idea": "[Best composite idea]",
          "intersection_reason": "[Synthesized reason]"
        }
      PROMPT

      response = CustomRubyLLM.context.chat.ask(prompt)
      json_str = response.content.gsub(/```json/i, "").gsub(/```/, "").strip
      JSON.parse(json_str)
    rescue => e
      Rails.logger.error("Aggregator failed: #{e.message}")
      { error: "Summary generation failed" }
    end
  end
end
