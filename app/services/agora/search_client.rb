require "google/cloud/discovery_engine"

module Agora
  class SearchClient
    def initialize
      # Uses Application Default Credentials (ADC) or GOOGLE_APPLICATION_CREDENTIALS
      @client = Google::Cloud::DiscoveryEngine.search_service
    end

    def search(query, num_results: 10, **options)
      project_id = ENV["GOOGLE_CLOUD_PROJECT"]
      data_store_id = ENV["DISCOVERY_ENGINE_DATA_STORE_ID"]

      unless project_id && data_store_id
        Rails.logger.error("[Agora::SearchClient] Missing Vertex AI config (GOOGLE_CLOUD_PROJECT, DISCOVERY_ENGINE_DATA_STORE_ID)")
        return []
      end

      # The 'serving_config' path is the modern 'cx' (Search Engine ID)
      serving_config = @client.serving_config_path(
        project:        project_id,
        location:       "global",
        data_store:     data_store_id,
        serving_config: "default_search"
      )

      # Basic Website Search in Vertex AI does not support date filtering.
      # We fetch more results and filter client-side in Ruby using extract_date.

      begin
        request = {
          serving_config: serving_config,
          query:          query,
          page_size:      num_results * 3 # Fetch extra to account for filtering
        }.merge(options)

        response = @client.search(request)

        results = response.map do |result|
          data = result.document.derived_struct_data.to_h
          {
            title: data["title"] || "Untitled",
            link:  data["link"] || "#",
            snippet: data.dig("snippets", 0, "snippet") || data.dig("pagemap", "metatags", 0, "og:description"),
            date: extract_date(data),
            source: "vertex_ai_search"
          }
        end

        results.take(num_results)

      rescue Google::Cloud::Error => e
        Rails.logger.error("[Agora::SearchClient] Vertex AI Search Error: #{e.message}")
        []
      rescue StandardError => e
        Rails.logger.error("[Agora::SearchClient] Error: #{e.message}")
        []
      end
    end

    private

    def extract_date(data)
      # Try to find date in metatags
      metatags = data.dig("pagemap", "metatags", 0) || {}

      date_str = metatags["article:published_time"] ||
                 metatags["date"] ||
                 metatags["pubdate"] ||
                 metatags["og:updated_time"]

      return Time.parse(date_str) if date_str.present?

      # Fallback: Try to extract from snippet
      # Matches: "Feb 29, 2024", "February 29, 2024", "2024-02-29"
      snippet = data.dig("snippets", 0, "snippet")
      if snippet && (match = snippet.match(/(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2}, \d{4}/))
        Time.parse(match[0])
      elsif snippet && (match = snippet.match(/\d{4}-\d{2}-\d{2}/))
        Time.parse(match[0])
      else
        nil
      end
    rescue ArgumentError
      nil
    end
  end
end
