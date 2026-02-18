require "httparty"
require "readability"
require "open-uri"

module Agora
  class ContentFetcher
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    def self.fetch(url)
      new(url).fetch
    end

    def initialize(url)
      @url = url
    end

    def fetch
      # 1. Fetch the HTML
      response = HTTParty.get(@url, headers: { "User-Agent" => USER_AGENT }, timeout: 10)
      return nil unless response.success?

      # 2. Parse and cleanup
      html = response.body
      doc = Readability::Document.new(html, tags: %w[div p h1 h2 h3 h4 h5 h6 ul ol li blockquote pre code], remove_empty_nodes: true)

      # 3. Extract content
      content = doc.content

      # Basic cleaning of the extracted HTML to plain text
      text = Nokogiri::HTML(content).text.strip
      puts "[Agora::ContentFetcher] Extracted #{text.length} chars from #{@url}"
      text
    rescue => e
      puts "[Agora::ContentFetcher] Error: #{e.message}"
      Rails.logger.error("[Agora::ContentFetcher] Failed to fetch #{@url}: #{e.message}")
      nil
    end
  end
end
