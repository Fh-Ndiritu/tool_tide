module TelegramNotifier
  class Subscriber
    def report(error, handled:, severity:, context:, source: nil)
      return if ignore?(error)

      message = Formatter.new(error, context: context).to_message
      Dispatcher.new.dispatch(message)
    rescue StandardError => e
      # Safety net: never let the error reporter crash the app
      Rails.logger.error("TelegramNotifier: Failed to report error: #{e.message}")
    end

    private

    def ignore?(error)
      return true unless TelegramNotifier.config.enabled
      return true if TelegramNotifier.config.ignored_exceptions.include?(error.class.name)

      # Optional: Ignore based on environment if needed, though we probably want to configure this via config.enabled
      false
    end
  end
end
