module TelegramNotifier
  class Formatter
    def initialize(error, context: {})
      @error = error
      @context = context
    end

    def to_message
      <<~MARKDOWN
        🚨 *Application Error*

        *Environment:* `#{Rails.env}`
        *Class:* `#{@error.class}`
        *Message:* #{@error.message.gsub(/[<>]/, '')}

        *Context:*
        ```json
        #{JSON.pretty_generate(@context).gsub('```', "'''")}
        ```

        *Backtrace:*
        ```
        #{formatted_backtrace}
        ```
      MARKDOWN
    end

    private

    def formatted_backtrace
      return "No backtrace available" unless @error.backtrace

      @error.backtrace.first(10).join("\n").gsub('```', "'''")
    end
  end
end
