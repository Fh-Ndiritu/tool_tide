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

      # 3.1 Institutional Memory
      context_parts << section("INSTITUTIONAL MEMORY (llms.txt)", load_context("llms.txt"))

      # 3.2 Corporate Memory (Learned Patterns) - Specific to Pitch
      corporate_memory = Agora::LearnedPattern.corporate_memory(limit: 5)
      context_parts << section("CORPORATE MEMORY (LEARNED PATTERNS)", corporate_memory) if corporate_memory.present?

      # 3.3 Trends (Last 24h, excluding active trends) - Specific logic
      trends_query = Agora::Trend.where(period: "daily")
                                 .where("created_at > ?", 24.hours.ago)
                                 .where.not(id: active_trends.pluck(:id))

      trends = trends_query.order(created_at: :desc).map do |t|
        "- #{t.content['trend_name']}: #{t.content['viral_hook_idea']}"
      end.join("\n")

      context_parts << section("CURRENT MARKET TRENDS (CONTEXT)", trends) if trends.present?

      # 3.4 Website Reference
      website_md = load_context("website.md")
      if website_md.present?
        remaining_budget = MAX_CHARS - context_parts.join.length
        if website_md.length > remaining_budget
          context_parts << section("WEBSITE REFERENCE (Truncated)", website_md[0...remaining_budget] + "\n...[TRUNCATED]")
        else
          context_parts << section("WEBSITE REFERENCE", website_md)
        end
      end

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

      # 1. High Priority: System Identity & llms.txt
      context_parts << section("INSTITUTIONAL MEMORY (llms.txt)", load_context("llms.txt"))

      # 2. Medium Priority: Trends (Recent)
      trends = Agora::Trend.order(created_at: :desc).limit(5).map do |t|
        "- #{t.content['trend_name']}: #{t.content['viral_hook_idea']}"
      end.join("\n")
      context_parts << section("CURRENT MARKET TRENDS", trends) if trends.present?

      # 3. Flexible Priority: website.md (Title + summary)
      website_md = load_context("website.md")
      if website_md.present?
        # If we have space, add full website.md, otherwise truncate
        remaining_budget = MAX_CHARS - context_parts.join.length
        if website_md.length > remaining_budget
          context_parts << section("WEBSITE REFERENCE (Truncated)", website_md[0...remaining_budget] + "\n...[TRUNCATED]")
        else
          context_parts << section("WEBSITE REFERENCE", website_md)
        end
      end

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
