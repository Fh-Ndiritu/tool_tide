# config/initializers/bria_ai.rb

require 'bria_ai'
BriaAi.configure do |config|
  config.api_token = ENV.fetch('BRIA_AI_API_TOKEN', nil)
  config.logger = Rails.logger # Use Rails' logger for better integration
  # You can set default_sync_mode here if you want all BriaAI calls to be synchronous by default
  # config.default_sync_mode = true
end
