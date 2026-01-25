require "rails_helper"

RSpec.describe SketchAnalysisJob, type: :job do
  let(:user) { User.create!(email: "test@example.com", password: "password", privacy_policy: true) }
  let(:canva) { Canva.create!(user: user) }
  # Mock CustomRubyLLM and response
  let(:llm_response) { double("Response", content: { "result" => { "image_type" => "sketch" } }) }
  let(:chat_context) { double("ChatContext") }
  let(:schema_context) { double("SchemaContext") }

  before do
    # Mock ActiveStorage
    allow(canva).to receive_message_chain(:image, :attached?).and_return(true)
    allow(canva).to receive_message_chain(:image, :content_type).and_return("image/jpeg")
    # Mock variant logic
    allow(canva).to receive_message_chain(:image, :variant, :processed, :download).and_return("fake image content")

    # Mock LLM
    allow(CustomRubyLLM).to receive_message_chain(:context, :chat).and_return(chat_context)
    allow(chat_context).to receive(:with_schema).and_return(schema_context)
    allow(schema_context).to receive(:ask).and_return(llm_response)

    # Mock Telegram Dispatcher
    allow_any_instance_of(TelegramNotifier::Dispatcher).to receive(:dispatch)
  end

  describe "#perform" do
    it "sends telegram notification when sketch is detected" do
      expect_any_instance_of(TelegramNotifier::Dispatcher).to receive(:dispatch)
        .with(include("Sketch/Satellite Detected"), image_io: instance_of(StringIO))

      described_class.perform_now(canva)
    end

    it "does not send telegram notification when photo is detected" do
      allow(llm_response).to receive(:content).and_return({ "result" => { "image_type" => "photo" } })

      expect_any_instance_of(TelegramNotifier::Dispatcher).not_to receive(:dispatch)

      described_class.perform_now(canva)
    end

    context "when image is not an image content type" do
      before do
        allow(canva).to receive_message_chain(:image, :content_type).and_return("video/mp4")
      end

      it "returns early and does not call LLM" do
        expect(CustomRubyLLM).not_to receive(:context)
        described_class.perform_now(canva)
      end
    end


  end
end
