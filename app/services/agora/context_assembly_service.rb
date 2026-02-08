module Agora
  class ContextAssemblyService
    # Conservative estimate: 1 token ~= 4 chars
    # Flash context window is huge, but we aim for "sweet spot" efficiency.
    MAX_CHARS = 100_000

    # Specific assembly for Pitch Generation (encapsulates trend selection logic)
    def assemble_for_pitch
      # 1. Select Fresh Trends (2 random daily trends from last 24h)
      active_trends = Agora::Trend.where(period: "daily")
                                  .where("created_at > ?", 24.hours.ago)
                                  .order("RANDOM()")
                                  .limit(2)

      return nil if active_trends.empty?

      # 2. Avoidance List (Recently accepted titles)
      avoidance_list = Agora::Post.accepted
                                  .where("created_at > ?", 24.hours.ago)
                                  .pluck(:title)
                                  .join(", ")

      # 3. Assemble Custom Context for Pitch
      context_parts = []

      # 3.1 Brand Context (website.md is the primary source)
      context_parts << section("BRAND CONTEXT", load_context("website.md"))

      # 3.2 Corporate Memory (Learned Patterns) - Specific to Pitch
      corporate_memory = Agora::LearnedPattern.corporate_memory(limit: 50)
      context_parts << section("CORPORATE MEMORY (LEARNED PATTERNS)", corporate_memory) if corporate_memory.present?

      # 3.3 Trends (Last 24h, excluding active trends) - Specific logic
      trends_query = Agora::Trend.where(period: "daily")
                                 .where("created_at > ?", 24.hours.ago)
                                 .where.not(id: active_trends.pluck(:id))

      trends = trends_query.order(created_at: :desc).map do |t|
        "- #{t.content['trend_name']}: #{t.content['viral_hook_idea']}"
      end.join("\n")

      context_parts << section("CURRENT MARKET TRENDS (CONTEXT)", trends) if trends.present?

      general_context = context_parts.join("\n\n---\n\n")

      # 4. Format Task Signals
      task_signals = active_trends.map do |t|
        "- #{t.content['trend_name']}: #{t.content['viral_hook_idea']} (Why: #{t.content['intersection_reason']})"
      end.join("\n")

      <<~BLOCK
        CONTEXT:
        #{general_context}

        TODAY'S TRENDING SIGNALS:
        #{task_signals}

        RECENTLY ACCEPTED IDEAS (DO NOT REPEAT):
        #{avoidance_list.presence || "None yet"}
      BLOCK
    end

    def assemble
      context_parts = []

      # 1. High Priority: Brand Context (website.md is the primary source)
      context_parts << section("BRAND CONTEXT", load_context("website.md"))

      # 2. Corporate Memory (Learned Patterns)
      corporate_memory = Agora::LearnedPattern.corporate_memory(limit: 50)
      context_parts << section("CORPORATE MEMORY (LEARNED PATTERNS)", corporate_memory) if corporate_memory.present?

      # 3. Medium Priority: Trends (Recent)
      trends = Agora::Trend.order(created_at: :desc).limit(5).map do |t|
        "- #{t.content['trend_name']}: #{t.content['viral_hook_idea']}"
      end.join("\n")

      context_parts << section("CURRENT MARKET TRENDS", trends) if trends.present?

      # Standardize format
      context_parts.join("\n\n---\n\n")
    end

    private

    def load_context(key)
      Agora::BrandContext.find_by(key: key)&.raw_content || "[#{key} MISSING]"
    end

    def section(header, content)
      <<~SECTION
        ## #{header}

        #{content}
      SECTION
    end
  end
end
