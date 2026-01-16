require "rails_helper"
require "telegram_notifier/subscriber"

RSpec.describe TelegramNotifier::Subscriber do
  let(:subscriber) { described_class.new }
  let(:error) { StandardError.new("Boom") }
  let(:config) { TelegramNotifier.config }

  before do
    TelegramNotifier.configure do |c|
      c.enabled = true
      c.ignored_exceptions = ["IgnoredError"]
    end
  end

  describe "#report" do
    it "delegates to Dispatcher" do
      expect_any_instance_of(TelegramNotifier::Dispatcher).to receive(:dispatch).with(kind_of(String))
      subscriber.report(error, handled: false, severity: :error, context: {})
    end

    it "ignores specific exceptions" do
      ignored_error = Class.new(StandardError)
      stub_const("IgnoredError", ignored_error)

      expect(TelegramNotifier::Dispatcher).not_to receive(:new)
      subscriber.report(ignored_error.new, handled: false, severity: :error, context: {})
    end

    it "does not raise error if dispatch fails" do
      allow(TelegramNotifier::Formatter).to receive(:new).and_raise("Formatter Error")
      expect(Rails.logger).to receive(:error).with(/Failed to report error/)

      expect {
        subscriber.report(error, handled: false, severity: :error, context: {})
      }.not_to raise_error
    end
  end
end
