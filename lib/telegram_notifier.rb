module TelegramNotifier
  require "telegram_notifier/dispatcher"
  require "telegram_notifier/formatter"
  require "telegram_notifier/subscriber"

  class << self
    attr_accessor :config

    def configure
      self.config ||= Configuration.new
      yield(config)
    end
  end

  class Configuration
    attr_accessor :bot_token, :chat_id, :enabled, :ignored_exceptions

    def initialize
      @enabled = true
      @ignored_exceptions = []
    end
  end
end
