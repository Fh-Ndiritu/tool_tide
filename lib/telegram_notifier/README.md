# Telegram Notifier

This module provides real-time error reporting to a Telegram chat by subscribing to the Rails Error Reporter API.

## How it Works

The system hooks into Rails' native error handling via `Rails.error.subscribe`.

### 1. Registration
In `config/initializers/telegram_notifier.rb`, we register the subscriber:

```ruby
Rails.error.subscribe(TelegramNotifier::Subscriber.new)
```

This tells Rails to notify our subscriber whenever `Rails.error.report` is called or when an unhandled exception occurs in a web request, background job, or Rake task.

### 2. Execution Flow

1.  **Error Occurs**: An exception is raised (e.g., in a Controller).
2.  **Rails Capture**: The Rails Error Reporter captures the exception.
3.  **Subscriber Notification**: The `report` method of `TelegramNotifier::Subscriber` is invoked with the error object and context.
4.  **Filtering**: The subscriber checks `TelegramNotifier.config` to see if the error class is ignored or if the notifier is disabled.
5.  **Formatting**: `TelegramNotifier::Formatter` converts the exception, backtrace, and context (params, user_id) into a Markdown-formatted string.
6.  **Dispatch**: `TelegramNotifier::Dispatcher` sends the message to the Telegram Bot API using Faraday.
    *   It includes a **Cooling Off** mechanism (5 minutes) to prevent notification storms for identical errors.

## Configuration

Set the configuration in `config/initializers/telegram_notifier.rb`:

```ruby
TelegramNotifier.configure do |config|
  config.bot_token = ENV["TELEGRAM_BOT_TOKEN"]
  config.chat_id = ENV["TELEGRAM_CHAT_ID"]
  config.enabled = Rails.env.production?
  config.ignored_exceptions = %w[ActiveRecord::RecordNotFound]
end
```

## Directory Structure

*   **`subscriber.rb`**: The entry point for Rails. Implements `#report`.
*   **`formatter.rb`**: Handles Markdown styling and data sanitization.
*   **`dispatcher.rb`**: Handles HTTP requests, rate limiting (caching), and error handling for the delivery itself.
