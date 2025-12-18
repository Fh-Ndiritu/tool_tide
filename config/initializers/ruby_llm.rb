# frozen_string_literal: true

RubyLLM.configure do |config|
  config.gemini_api_key = ENV["GEMINI_API_KEY"]
  config.mistral_api_key = ENV["MISTRAL_API_KEY"]

  config.default_model = "gemini-2.0-flash"

  config.request_timeout = 300
  config.max_retries = 4

  # Advanced retry behavior
  config.retry_interval = 1 # Initial retry delay in seconds (default: 0.1)
  config.retry_backoff_factor = 2 # Exponential backoff multiplier (default: 2)
  config.retry_interval_randomness = 0.5 # Jitter to prevent thundering herd (default: 0.5)
end

class CustomRubyLLM
  def self.context
    RubyLLM.configure do |config|
      config.gemini_api_key = ENV["GEMINI_API_KEYS"].split("__").sample
    end
    RubyLLM
  end
end
