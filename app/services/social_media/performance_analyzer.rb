module SocialMedia
  class PerformanceMetricSchema < RubyLLM::Schema
    object :metrics do
      integer :reach, description: "Total reach of the post"
      integer :engagement, description: "Total engagement count"
      integer :reactions, description: "Number of reactions"
      integer :comments, description: "Number of comments"
      integer :shares, description: "Number of shares"
      integer :link_clicks, description: "Number of link clicks"
    integer :performance_score, description: "Calculate a score from 0 to 100 based on these metrics relative to a 'viral' post (e.g. 10k reach is 100)"
    end
  end

  class PerformanceAnalyzer
    def self.perform(social_post)
      new(social_post).analyze
    end

    def initialize(social_post)
      @social_post = social_post
    end

    def analyze
      return unless @social_post.performance_screenshot.attached?

      prompt = "Analyze this Facebook performance screenshot. Extract the visible key metrics."

      response = CustomRubyLLM.context.chat.with_schema(PerformanceMetricSchema).ask(
        prompt,
        with: @social_post.performance_screenshot
      )
      data = response.content["metrics"]

      if data
        @social_post.update!(
          performance_metrics: data.except("performance_score"),
          performance_score: data["performance_score"]
        )
      end
    rescue StandardError => e
      Rails.logger.error("Performance Analysis Failed: #{e.message}")
    end
  end
end
