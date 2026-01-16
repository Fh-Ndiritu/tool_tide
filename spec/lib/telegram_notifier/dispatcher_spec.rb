require "rails_helper"
require "telegram_notifier/dispatcher"

RSpec.describe TelegramNotifier::Dispatcher do
  let(:dispatcher) { described_class.new }
  let(:message) { "Test message" }
  let(:config) { TelegramNotifier.config }

  before do
    TelegramNotifier.configure do |c|
      c.bot_token = "TEST_TOKEN"
      c.chat_id = "TEST_CHAT_ID"
      c.enabled = true
    end

    # Mock Rails.cache
    allow(Rails.cache).to receive(:exist?).and_return(false)
    allow(Rails.cache).to receive(:write)
  end

  describe "#dispatch" do
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:conn) do
      Faraday.new do |b|
        b.adapter :test, stubs
      end
    end

    before do
      allow(dispatcher).to receive(:client).and_return(conn)
    end

    it "sends a POST request to Telegram API" do
      stubs.post("/botTEST_TOKEN/sendMessage") do |env|
        expect(env.body).to include("Test message")
        expect(env.body).to include("TEST_CHAT_ID")
        [200, {}, { ok: true }.to_json]
      end

      dispatcher.dispatch(message)
      stubs.verify_stubbed_calls
    end

    it "does not send if disabled" do
      config.enabled = false
      expect(dispatcher).not_to receive(:client)
      dispatcher.dispatch(message)
    end

    it "does not send if config is missing" do
      config.bot_token = nil
      expect(dispatcher).not_to receive(:client)
      dispatcher.dispatch(message)
    end

    it "does not send if cooling off" do
      allow(Rails.cache).to receive(:exist?).and_return(true)
      expect(dispatcher).not_to receive(:client)
      dispatcher.dispatch(message)
    end

    it "logs error on failure" do
      stubs.post("/botTEST_TOKEN/sendMessage") do
        [400, {}, "Bad Request"]
      end

      expect(Rails.logger).to receive(:error).with(/Failed to send message/)
      dispatcher.dispatch(message)
    end
  end
end
