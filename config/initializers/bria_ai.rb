# config/initializers/bria_ai.rb

require_relative "../../lib/bria_ai" # Add this line to explicitly load the module

BriaAI.configure do |config|
  config.api_token = ENV["BRIA_AI_API_TOKEN"]
  config.logger = Rails.logger # Use Rails' logger for better integration
  # You can set default_sync_mode here if you want all BriaAI calls to be synchronous by default
  # config.default_sync_mode = true
end
