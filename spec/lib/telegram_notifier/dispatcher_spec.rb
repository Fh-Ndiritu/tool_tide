require "rails_helper"

RSpec.describe TelegramNotifier::Dispatcher do
  let(:config) { TelegramNotifier::Configuration.new }
  let(:dispatcher) { described_class.new }
  let(:faraday_client) { instance_double(Faraday::Connection) }
  let(:faraday_response) { instance_double(Faraday::Response, success?: true, status: 200, body: "{}") }

  before do
    allow(TelegramNotifier).to receive(:config).and_return(config)
    config.bot_token = "test_token"
    config.chat_id = "123456"
    config.enabled = true

    # Mock Rails.cache
    allow(Rails.cache).to receive(:exist?).and_return(false)
    allow(Rails.cache).to receive(:write)

    # Mock Faraday
    allow(Faraday).to receive(:new).and_return(faraday_client)
    allow(faraday_client).to receive(:post).and_yield(double("request", headers: {}, :body= => nil)).and_return(faraday_response)
  end

  describe "#dispatch" do
    let(:message) { "Test message" }

    it "sends a text message when no image URL is provided" do
      req = double("request", headers: {})
      allow(req).to receive(:body=)

      expect(faraday_client).to receive(:post).with("/bottest_token/sendMessage").and_yield(req).and_return(faraday_response)
      dispatcher.dispatch(message)
    end

    it "sends a photo message when image URL is provided" do
      image_url = "https://example.com/image.jpg"
      req = double("request", headers: {})
      allow(req).to receive(:body=)

      expect(faraday_client).to receive(:post).with("/bottest_token/sendPhoto").and_yield(req).and_return(faraday_response)
      dispatcher.dispatch(message, image_url: image_url)
    end

    it "does not send message if disabled" do
      config.enabled = false
      expect(Faraday).not_to receive(:new)
      dispatcher.dispatch(message)
    end

    it "does not send message if cooling off" do
      allow(Rails.cache).to receive(:exist?).and_return(true)
      expect(Faraday).not_to receive(:new)
      dispatcher.dispatch(message)
    end
  end
end
