# frozen_string_literal: true

RubyLLM.configure do |config|
  config.gemini_api_key = ENV["GEMINI_API_KEY"]
  config.mistral_api_key = ENV["MISTRAL_API_KEY"]

  config.default_model = "gemini-2.0-flash"

  # Connection settings
  config.timeout = 120 # seconds
  config.open_timeout = 120 # seconds

  # Retry settings
  config.max_retries = 3
  config.retry_interval = 2 # seconds
end
