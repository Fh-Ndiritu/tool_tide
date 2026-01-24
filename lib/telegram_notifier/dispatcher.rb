require "faraday"
require "faraday/multipart"

module TelegramNotifier
  class Dispatcher
    TELEGRAM_API_URL = "https://api.telegram.org"
    CACHE_KEY_PREFIX = "telegram_error_notification"
    COOLING_PERIOD = 5.minutes

    def initialize
      @config = TelegramNotifier.config
    end

    def dispatch(message, image_url: nil, image_io: nil)
      return unless @config.enabled

      return if @config.bot_token.blank? || @config.chat_id.blank?

      # Use a hash of the message to debounce identical errors
      message_hash = Digest::SHA256.hexdigest(message + image_url.to_s + image_io.to_s)
      return if cooling_off?(message_hash)

      token = @config.bot_token.to_s.strip
      # Ensure accidental 'bot' prefix from copy-paste is handled if user added it
      token = token.sub(/^bot/i, "") if token.match?(/^bot\d+:/i)

      endpoint = (image_url || image_io) ? "sendPhoto" : "sendMessage"

      begin
        response = client.post("/bot#{token}/#{endpoint}") do |req|
          payload = {
            chat_id: @config.chat_id,
            parse_mode: "Markdown"
          }

          if image_url
            payload[:photo] = image_url
            payload[:caption] = message
          elsif image_io
            payload[:photo] = Faraday::Multipart::FilePart.new(
              image_io,
              "image/jpeg", # Default to jpeg, or detect if possible, but Telegram usually handles it
              "image.jpg"
            )
            payload[:caption] = message
          else
            payload[:text] = message
          end

          unless image_io
            req.body = payload.to_json
            req.headers["Content-Type"] = "application/json"
          else
            req.body = payload
            # Content-Type header is set automatically by multipart middleware
          end
        end

        unless response.success?
          Rails.logger.error("TelegramNotifier: Failed to send message. Status: #{response.status}, Body: #{response.body}")
        end

        mark_as_sent(message_hash)
      rescue Faraday::Error => e
        Rails.logger.error("TelegramNotifier: Network error: #{e.message}")
      end
    end

    private

    def client
      @client ||= Faraday.new(url: TELEGRAM_API_URL) do |f|
        f.request :multipart
        f.request :retry, max: 2, interval: 0.5
        f.adapter Faraday.default_adapter
      end
    end

    def cooling_off?(hash)
      Rails.cache.exist?("#{CACHE_KEY_PREFIX}:#{hash}")
    end

    def mark_as_sent(hash)
      Rails.cache.write("#{CACHE_KEY_PREFIX}:#{hash}", true, expires_in: COOLING_PERIOD)
    end
  end
end
