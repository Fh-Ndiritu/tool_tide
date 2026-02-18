module Agora
  class OpportunityScout
    # Targeted platforms and their search query patterns
    PLATFORMS = {
      reddit: "site:reddit.com",
      linkedin: "site:linkedin.com/posts OR site:linkedin.com/feed",
      facebook: "site:facebook.com",
      pinterest: "site:pinterest.com",
      instagram: "site:instagram.com"
    }

    # Schema for generating search keywords
    class KeywordGenerationSchema < RubyLLM::Schema
      object :result do
        array :keywords, description: "List of 5 specific search queries related to the brand context" do
          string :query, description: "The specific search query string related to the brand context"
        end
      end
    end

    def self.run
      new.run
    end

    def initialize
      @search_client ||= Agora::SearchClient.new
    end

    def run
      PLATFORMS.each_key do |platform|
        scout_platform(platform)
      end
    end

    private

    def scout_platform(platform)
      # 1. Generate Dynamic Keywords (Problem-Centric)
      keywords = generate_keywords(platform)
      found_count = 0
      keywords.each do |keyword|
        break if found_count >= 5 # Quota per platform/run

        # 2. Execute Search with Freshness Filter
        query = construct_query(platform, keyword)

        # Enforce 1-year freshness
        results = @search_client.search(query, num_results: 10)

        # 3. Filter & Save
        results.each do |result|
          next unless valid_result?(result)

          # 4. Enrich & Save
          if save_opportunity(result, platform)
            found_count += 1
            break if found_count >= 4
          end
        end
      end
    end

    def generate_keywords(platform)
      context = Agora::ContextAssemblyService.new.assemble

      prompt = <<~PROMPT
        You are a "Strategic Problem Hunter" specializing in social listening and intent discovery.

        OBJECTIVE:
        Analyze the BRAND CONTEXT and generate 5 specific, high-intent "Problem-Solution" search queries as if you are a user looking for a solution to a problem.
        Your goal is to find users who are expressing a specific frustration, asking for a recommendation, or seeking a DIY workaround that this brand solves.

        STRATEGY:
        Vary the intent of the queries across these categories:
        1. Direct Pain (e.g., "how to fix...", "struggling with...")
        2. Tool Seeking (e.g., "recommendation for...", "app that does...")
        3. Cost/Complexity Alternative (e.g., "cheaper way to...", "do I really need an architect for...")

        BRAND CONTEXT:
        #{context[0..40_000]}

        GUIDELINES:
        - BE SPECIFIC: Avoid generic industry terms. Instead of "landscaping," use the specific nouns found in the Brand Context (e.g., "retaining wall," "shade garden," "deck layout").
        - THINK LIKE A USER: Use natural, conversational language that people actually type into search bars.
        - NO OVERLAP: Ensure each of the 5 queries targets a slightly different sub-problem.
        - DO NOT mention the platform name in the queries.

        OUTPUT:
        - Return ONLY the search strings.
        - One query per line.
        - Do NOT include "site:..." prefixes or quotes unless they are part of the natural search.
        - Do NOT include reference to Google, the brand or a specific social platform.
      PROMPT

      response = CustomRubyLLM.context.chat.with_schema(KeywordGenerationSchema).ask(prompt)
      response.content.dig("result", "keywords")
    rescue => e
      Rails.logger.error("Keyword generation failed: #{e.message}")
      [ "how to visualize garden", "backyard design app help" ] # Fallback
    end

    def construct_query(platform, keyword)
      "#{PLATFORMS[platform]} #{keyword}"
    end

    def valid_result?(result)
      return false if result[:link].blank?

      # Deduplication
      !Agora::Opportunity.exists?(url: result[:link])
    end

    def save_opportunity(result, platform)
      # Fetch full content for better context
      full_content = Agora::ContentFetcher.fetch(result[:link])

      Agora::Opportunity.create(
        url: result[:link],
        title: result[:title],
        content_snippet: result[:snippet],
        content: full_content, # New field
        platform: platform,
        posted_at: result[:date] || Time.current,
        status: "pending"
      )
    rescue ActiveRecord::RecordNotUnique
      false
    end
  end
end
