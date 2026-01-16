require "rails_helper"
require "telegram_notifier/formatter"

RSpec.describe TelegramNotifier::Formatter do
  let(:error) { StandardError.new("Something went wrong") }
  let(:context) { { user_id: 1, params: { foo: "bar" } } }
  let(:formatter) { described_class.new(error, context: context) }

  describe "#to_message" do
    it "formats the error message correctly" do
      message = formatter.to_message
      expect(message).to include("*Application Error*")
      expect(message).to include("*Class:* `StandardError`")
      expect(message).to include("*Message:* Something went wrong")
    end

    it "includes the context" do
      message = formatter.to_message
      expect(message).to include('"user_id": 1')
      expect(message).to include('"foo": "bar"')
    end

    it "includes the backtrace if available" do
      error.set_backtrace(["line1", "line2", "line3"])
      message = formatter.to_message
      expect(message).to include("line1")
      expect(message).to include("line3")
    end

    it "handles missing backtrace" do
      allow(error).to receive(:backtrace).and_return(nil)
      message = formatter.to_message
      expect(message).to include("No backtrace available")
    end

    it "sanitizes HTML characters in message" do
      error = StandardError.new("<script>alert('xss')</script>")
      formatter = described_class.new(error)
      expect(formatter.to_message).to include("scriptalert('xss')/script")
    end
  end
end
