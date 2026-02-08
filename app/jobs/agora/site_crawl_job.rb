require "faraday/follow_redirects"

module Agora
  class SiteCrawlJob < ApplicationJob
    queue_as :default

    # Schema for website summary
    class WebsiteSummarySchema < RubyLLM::Schema
      object :result do
        string :markdown_content, description: "The full markdown content summarizing the website's features, purpose, and value propositions"
      end
    end

    # Schema for discovering feature pages to crawl
    class DiscoverPagesSchema < RubyLLM::Schema
      array :pages, description: "List of up to 5 additional pages to crawl" do
        object do
          string :url, description: "Full URL of the page to crawl"
          string :reason, description: "Why this page has feature/documentation value"
        end
      end
    end

    # Schema for llms.txt generation
    class LlmsTxtSchema < RubyLLM::Schema
      object :result do
        string :markdown_content, description: "The llms.txt content - a high-level sitemap and summary for LLM agents"
      end
    end

    # Schema for llms-full.txt generation
    class LlmsFullTxtSchema < RubyLLM::Schema
      object :result do
        string :markdown_content, description: "The llms-full.txt content - deep documentation and detailed context for LLM agents"
      end
    end

    def perform(website_url:, llms_txt_url: nil, llms_full_txt_url: nil)
      @source_urls = { website_url: website_url }

      broadcast_status("🚀 Starting crawl of #{website_url}...", type: :info)

      # 1. Fetch and process homepage
      site_content = fetch_content(website_url)
      homepage_md = html_to_markdown(site_content)

      # 2. Try to fetch existing llms files EARLY (to incorporate into summary)
      broadcast_status("🔍 Checking for existing llms.txt files...", type: :info)
      llms_txt_content = try_fetch_llms_file(website_url, "/llms.txt")
      llms_full_txt_content = try_fetch_llms_file(website_url, "/llms-full.txt")

      # 3. Discover additional feature pages using LLM
      broadcast_status("🔍 Discovering feature pages...", type: :info)
      feature_pages = discover_feature_pages(homepage_md, website_url)

      # 4. Crawl all discovered pages
      all_page_contents = [ homepage_md ]
      feature_pages.each_with_index do |page, index|
        begin
          broadcast_status("📄 Crawling page #{index + 1}/#{feature_pages.length}: #{page['url']}...", type: :info)
          page_content = fetch_content(page["url"])
          page_md = html_to_markdown(page_content)
          all_page_contents << "\n\n---\n## Page: #{page['url']}\n### Reason: #{page['reason']}\n\n#{page_md}"
        rescue StandardError => e
          Rails.logger.warn("[SiteCrawlJob] Failed to fetch #{page['url']}: #{e.message}")
        end
      end

      # 5. Build combined content for summarization (include llms files if found)
      combined_content = all_page_contents.join("\n\n")
      if llms_txt_content
        combined_content += "\n\n---\n## Existing llms.txt (official site context):\n#{llms_txt_content}"
      end
      if llms_full_txt_content
        combined_content += "\n\n---\n## Existing llms-full.txt (official deep documentation):\n#{llms_full_txt_content}"
      end

      # 6. Summarize combined content into website.md
      broadcast_status("📄 Summarizing #{all_page_contents.length} pages...", type: :info)
      website_md = summarize_site(combined_content)

      # 7. If llms files were NOT found, auto-generate them from website.md
      if llms_txt_content.nil?
        broadcast_status("⚠️ llms.txt not found, generating...", type: :info)
        llms_txt_content = generate_llms_txt(website_md)
        llms_txt_source = "generated_by_ai"
      else
        llms_txt_source = "fetched_from_url"
      end

      if llms_full_txt_content.nil?
        broadcast_status("⚠️ llms-full.txt not found, generating...", type: :info)
        llms_full_txt_content = generate_llms_full_txt(website_md)
        llms_full_txt_source = "generated_by_ai"
      else
        llms_full_txt_source = "fetched_from_url"
      end

      # 8. Atomic upsert - store all context
      # Note: llms files are stored for users to download, but website.md is the primary source
      ActiveRecord::Base.transaction do
        Agora::BrandContext.delete_all
        upsert_context("website.md", website_md, source: "generated_by_ai", origin_url: website_url)
        upsert_context("llms.txt", llms_txt_content, source: llms_txt_source, origin_url: website_url)
        upsert_context("llms-full.txt", llms_full_txt_content, source: llms_full_txt_source, origin_url: website_url)
      end

      broadcast_list
      broadcast_status("✅ Crawl complete!", type: :success)
      Rails.logger.info("[SiteCrawlJob] Successfully crawled and processed #{website_url}")
    rescue StandardError => e
      broadcast_status("❌ Error: #{e.message}", type: :error)
      Rails.logger.error("[SiteCrawlJob] Failed to fetch #{website_url}: #{e.class} - #{e.message}")
      raise e
    end

    private

    def broadcast_status(message, type: :info)
      color = type == :error ? "red" : (type == :success ? "green" : "blue")

      html = <<~HTML
        <div class="bg-#{color}-900/50 border border-#{color}-700 text-#{color}-300 px-4 py-3 rounded-lg mb-6 animate-pulse">
          #{message}
        </div>
      HTML

      Turbo::StreamsChannel.broadcast_update_to(
        "brand_context_updates",
        target: "brand_context_status",
        html: html
      )
    end

    def broadcast_list
      brand_contexts = Agora::BrandContext.all.order(:key)

      html = ApplicationController.render(
        partial: "agora/brand_contexts/list",
        locals: {
          brand_contexts: brand_contexts,
          website_context: brand_contexts.find_by(key: "website.md"),
          llms_txt: brand_contexts.find_by(key: "llms.txt"),
          llms_full_txt: brand_contexts.find_by(key: "llms-full.txt")
        }
      )

      Turbo::StreamsChannel.broadcast_update_to(
        "brand_context_updates",
        target: "brand_context_list",
        html: html
      )
    end

    def upsert_context(key, content, source:, origin_url:)
      context = Agora::BrandContext.find_or_initialize_by(key: key)
      current_metadata = @source_urls.merge({
        "source_type" => source,
        "origin_url" => origin_url
      })

      context.update!(
        raw_content: content,
        last_crawled_at: Time.current,
        metadata: current_metadata
      )
    end

    def fetch_content(url)
      conn = Faraday.new do |f|
        f.headers["User-Agent"] = "Mozilla/5.0 (compatible; SiteCrawlBot/1.0; +https://hadaa.app)"
        f.headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        f.request :url_encoded
        f.response :follow_redirects
        f.adapter Faraday.default_adapter
        f.options.timeout = 30
        f.options.open_timeout = 10
        f.ssl.verify = false # Some sites have SSL issues
      end

      response = conn.get(url)
      Rails.logger.info("[SiteCrawlJob] Fetched #{url} - Status: #{response.status}, Size: #{response.body.length} bytes")

      if response.success?
        body = response.body
        # Force encoding to UTF-8 and replace invalid/undefined characters
        if body.encoding == Encoding::ASCII_8BIT
          body.force_encoding("UTF-8")
        end

        unless body.valid_encoding?
          body = body.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        end

        body
      else
        raise StandardError, "HTTP #{response.status}"
      end
    rescue StandardError => e
      Rails.logger.error("[SiteCrawlJob] Failed to fetch #{url}: #{e.class} - #{e.message}")
      raise e
    end

    def html_to_markdown(html)
      doc = Nokogiri::HTML(html)

      # Remove noise
      %w[script style iframe noscript].each do |tag|
        doc.css(tag).remove
      end

      ReverseMarkdown.convert(doc.to_s, github_style: true)
    end

    def summarize_site(markdown)
      prompt = <<~PROMPT
        You are an expert site analyzer extracting marketing intelligence.

        Analyze the following website content and produce a structured summary.

        OUTPUT FORMAT (use exactly these sections):

        # Brand Overview
        - Company name and tagline
        - Core value proposition (1-2 sentences)
        - Target audience

        # Key Features
        List each distinct feature with:
        - **Feature Name**: Brief description of what it does
        - Focus on UNIQUE capabilities, not generic claims

        # Differentiation
        - What makes this different from competitors?
        - Unique technology, approach, or positioning

        # Use Cases
        - Primary use cases or customer scenarios
        - Who benefits most from this product?

        # Pricing/Business Model
        - Pricing tiers if mentioned
        - Free trial, freemium, or paid only

        # Social Proof
        - Testimonials, case studies, or notable clients mentioned

        REQUIREMENTS:
        - Be specific and concrete, avoid marketing fluff
        - Extract actual feature names and capabilities
        - If information is not available, write "Not mentioned"
        - Output strictly in GitHub Flavored Markdown format

        RAW CONTENT:
        #{markdown[0..150_000]}
      PROMPT

      generate_with_llm(prompt, WebsiteSummarySchema)
    end

    # Try to fetch an llms file from the website, return nil if not found
    def try_fetch_llms_file(base_url, path)
      begin
        uri = URI.parse(base_url)
        target_url = URI.join("#{uri.scheme}://#{uri.host}", path).to_s
        content = fetch_content(target_url)
        return content if content.present? && content.length > 50
      rescue StandardError => e
        Rails.logger.info("[SiteCrawlJob] #{path} not found: #{e.message}")
      end
      nil
    end

    def generate_llms_txt(website_md)
      prompt = <<~PROMPT
        Generate an 'llms.txt' file based on the following website summary.
        The 'llms.txt' should be a high-level sitemap and summary for LLM agents.

        Follow the llms.txt standard format:
        - Start with a brief description of the site
        - List key pages and their purposes
        - Include relevant metadata

        Output strictly in plain text/markdown format.

        WEBSITE CONTEXT:
        #{website_md}
      PROMPT
      generate_with_llm(prompt, LlmsTxtSchema)
    end

    def generate_llms_full_txt(website_md)
      prompt = <<~PROMPT
        Generate an 'llms-full.txt' file based on the following website summary.
        The 'llms-full.txt' should contain deep documentation and detailed context for LLM agents.

        Include:
        - Complete feature documentation
        - Use cases and examples
        - Technical details if available
        - Any pricing or business model information

        Output strictly in plain text/markdown format.

        WEBSITE CONTEXT:
        #{website_md}
      PROMPT
      generate_with_llm(prompt, LlmsFullTxtSchema)
    end

    def discover_feature_pages(homepage_md, base_url)
      prompt = <<~PROMPT
        Analyze this homepage and identify up to 5 additional pages that would contain:
        - Detailed feature documentation
        - How-to/tutorial content
        - Use cases and examples
        - Pricing/plans information
        - About/company information

        Base URL: #{base_url}

        Homepage Content (analyze for links):
        #{homepage_md[0..30000]}

        Return only URLs that:
        1. Are on the same domain
        2. Would provide valuable feature/documentation context
        3. Are likely to have substantive content (not privacy policy, terms, etc.)

        Return an empty array if you cannot identify any suitable pages.
      PROMPT

      response = CustomRubyLLM.context.chat.with_schema(DiscoverPagesSchema).ask(prompt)
      pages = response.content["pages"] || []

      # Validate and filter pages
      pages.select do |page|
        url = page["url"].to_s
        url.present? && url.start_with?("http") && !url.include?("/privacy") && !url.include?("/terms")
      end.first(5)
    rescue StandardError => e
      Rails.logger.warn("[SiteCrawlJob] Failed to discover feature pages: #{e.message}")
      []
    end

    def generate_with_llm(prompt, schema)
      response = CustomRubyLLM.context.chat.with_schema(schema).ask(prompt)
      response.content.dig("result", "markdown_content") || response.content.to_s
    rescue StandardError => e
      Rails.logger.error("LLM Generation failed: #{e.message}")
      "Error generating content. Please verify manually."
    end
  end
end
