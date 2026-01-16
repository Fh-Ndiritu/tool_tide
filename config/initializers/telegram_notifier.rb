require "telegram_notifier"

TelegramNotifier.configure do |config|
  config.bot_token = ENV["TELEGRAM_BOT_TOKEN"]
  config.chat_id = ENV["TELEGRAM_CHAT_ID"]
  config.enabled = Rails.env.production? || Rails.env.staging? || ENV["ENABLE_TELEGRAM_NOTIFIER"] == "true"

  # Add common noise exceptions here
  config.ignored_exceptions = %w[
    ActionController::RoutingError
    ActiveRecord::RecordNotFound
  ]
end

# Subscribe to Rails error reporter
Rails.error.subscribe(TelegramNotifier::Subscriber.new)
