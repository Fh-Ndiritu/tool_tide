module Agora
  class ContextAssemblyService
    # Conservative estimate: 1 token ~= 4 chars
    # Flash context window is huge, but we aim for "sweet spot" efficiency.
    MAX_CHARS = 100_000

    def assemble
      context_parts = []

      # 1. High Priority: System Identity & llms.txt
      context_parts << section("INSTITUTIONAL MEMORY (llms.txt)", load_context("llms.txt"))

      # 2. Medium Priority: Trends (Recent)
      trends = Agora::Trend.order(created_at: :desc).limit(5).map { |t| t.content.to_s }.join("\n")
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
