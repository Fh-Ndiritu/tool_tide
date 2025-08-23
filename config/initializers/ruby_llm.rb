RubyLLM.configure do |config|
  config.gemini_api_key = ENV["GEMINI_API_KEY"]
  config.mistral_api_key = ENV["MISTRAL_API_KEY"]

  config.default_model = "gemini-2.0-flash"
end
