# frozen_string_literal: true

# Schema for structured trend output
class TrendDiscoverySchema < RubyLLM::Schema
  array :trends, description: "List of discovered marketing trends" do
    object :trend do
      string :trend_name, description: "Name of the marketing trend"
      integer :signal_strength, description: "How strong this signal is (1-10)"
      string :viral_hook_idea, description: "A creative hook to leverage this trend"
      string :intersection_reason, description: "Why this trend fits our brand"
      string :source_url, description: "URL source if available"
    end
  end
end

module Agora
  class TrendHunterJob < ApplicationJob
    queue_as :default

    def perform
      # 1. Gather Institutional Truth
      assembler = Agora::ContextAssemblyService.new
      context = assembler.assemble

      # 1.1 Fetch Recent History (Last 48h) to avoid repetition
      recent_trends = Agora::Trend.where(period: "daily")
                                  .where("created_at > ?", 48.hours.ago)
                                  .pluck(:content)
                                  .map { |c| c["trend_name"] }
                                  .compact
                                  .join(", ")

      # 2. Hunt for Trends (Gemini)
      agent_config = AGORA_HEAD_HUNTER
      model_id = agent_config[:model_name]
      trends_data = search_trends(context, recent_trends, model_id)

      # 3. Store valid trends
      trends_data.each do |trend_data|
        Agora::Trend.create!(
          period: "daily",
          content: trend_data.except("source_url"),
          source_metadata: { url: trend_data["source_url"] }.compact
        )
      end

      Rails.logger.info("TrendHunterJob: Discovered #{trends_data.count} new trends")
      trends_data
    end

    private

    def search_trends(context, recent_trends, model_id)
      prompt = <<~PROMPT
        You are #{AGORA_HEAD_HUNTER[:user_name]}, the "Trend Hunter" for our brand.

        INSTITUTIONAL CONTEXT:
        #{context}

        RECENTLY DISCOVERED TRENDS (DO NOT REPEAT THESE):
        #{recent_trends.presence || "None yet"}

        TASK:
        Identify 3-5 NEW, high-engagement marketing trends relevant to our brand's industry.
        For each trend, explain why it intersects with our brand positioning.
        Focus on trends from #{Time.current.year} that have viral potential.
      PROMPT

      # Use structured schema output
      response = CustomRubyLLM.context(model: model_id)
                              .chat
                              .with_schema(TrendDiscoverySchema)
                              .ask(prompt)

      # Parse the structured response
      result = response.content
      result["trends"] || []
    rescue => e
      Rails.logger.error("TrendHunterJob failed: #{e.class} - #{e.message}")
      []
    end
  end
end
