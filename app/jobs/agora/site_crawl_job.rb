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
      @source_urls = {
        website_url: website_url,
        llms_txt_url: llms_txt_url,
        llms_full_txt_url: llms_full_txt_url
      }

      broadcast_status("🚀 Starting crawl of #{website_url}...", type: :info)

      # 1. Process Website Content
      site_content = fetch_content(website_url)

      broadcast_status("📄 Summarizing website content...", type: :info)
      markdown_content = html_to_markdown(site_content)
      website_md = summarize_site(markdown_content)

      # 2. Process llms.txt
      broadcast_status("🤖 Processing llms.txt...", type: :info)
      llms_txt_result = fetch_or_generate(
        user_provided_url: llms_txt_url,
        default_path: "/llms.txt",
        base_url: website_url,
        type: :llms_txt,
        base_context: website_md
      )

      # 3. Process llms-full.txt
      broadcast_status("📚 Processing llms-full.txt...", type: :info)
      llms_full_txt_result = fetch_or_generate(
        user_provided_url: llms_full_txt_url,
        default_path: "/llms-full.txt",
        base_url: website_url,
        type: :llms_full_txt,
        base_context: website_md
      )

      # 4. Atomic upsert - delete old and insert new in transaction
      ActiveRecord::Base.transaction do
        Agora::BrandContext.delete_all
        upsert_context("website.md", website_md, source: "generated_by_ai", origin_url: website_url)
        upsert_context("llms.txt", llms_txt_result[:content], source: llms_txt_result[:source], origin_url: llms_txt_result[:url])
        upsert_context("llms-full.txt", llms_full_txt_result[:content], source: llms_full_txt_result[:source], origin_url: llms_full_txt_result[:url])
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
      %w[nav footer script style iframe noscript].each do |tag|
        doc.css(tag).remove
      end

      ReverseMarkdown.convert(doc.to_s, github_style: true)
    end

    def summarize_site(markdown)
      prompt = <<~PROMPT
        You are an expert site analyzer.
        Summarize the following raw website markdown into a concise, high-density description of the site's features, purpose, and key value propositions.
        Output strictly in Markdown format.

        RAW CONTENT:
        #{markdown[0..50000]}
      PROMPT

      generate_with_llm(prompt, WebsiteSummarySchema)
    end

    def fetch_or_generate(user_provided_url:, default_path:, base_url:, type:, base_context:)
      # 1. Determine target URL (User provided OR guess default)
      target_url = user_provided_url.presence

      if target_url.blank?
        begin
          uri = URI.parse(base_url)
          target_url = URI.join("#{uri.scheme}://#{uri.host}", default_path).to_s
        rescue StandardError
          target_url = nil
        end
      end

      # 2. Try fetching if we have a URL
      if target_url.present?
        begin
          broadcast_status("🔍 Checking #{target_url}...", type: :info)
          content = fetch_content(target_url)

          if content.present? && content.length > 50
             return { content: content, source: "fetched_from_url", url: target_url }
          end
        rescue StandardError => e
          Rails.logger.warn("Failed to fetch #{target_url}, falling back to generation: #{e.message}")
        end
      end

      # 3. Generate if missing or fetch failed
      broadcast_status("⚠️ #{default_path} not found, generating via AI...", type: :info)

      generated_content = case type
      when :llms_txt
        prompt = <<~PROMPT
          Generate an 'llms.txt' file based on the following website summary.
          The 'llms.txt' should be a high-level sitemap and summary for LLM agents.
          Output strictly in plain text/markdown format.

          WEBSITE CONTEXT:
          #{base_context}
        PROMPT
        generate_with_llm(prompt, LlmsTxtSchema)

      when :llms_full_txt
        prompt = <<~PROMPT
          Generate an 'llms-full.txt' file based on the following website summary.
          The 'llms-full.txt' should contain deep documentation and detailed context for LLM agents.
          Output strictly in plain text/markdown format.

          WEBSITE CONTEXT:
          #{base_context}
        PROMPT
        generate_with_llm(prompt, LlmsFullTxtSchema)
      end

      { content: generated_content, source: "generated_by_ai", url: nil }
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
