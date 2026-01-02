require 'rails_helper'

RSpec.describe DesignGenerator do
  # fixtures :users, :canvas, :mask_requests, :credits

  let(:user) { User.create!(email: 'test_service@example.com', password: 'password', pro_engine_credits: 0, privacy_policy: true) }
  let(:canva) { Canva.create!(user: user) }
  let(:mask_request) { MaskRequest.create!(canva: canva, progress: :preparing, preset: "modern") }
  let(:generator) { DesignGenerator.new(mask_request) }

  before do
    # Mock GCP calls to avoid external requests
    allow(generator).to receive(:fetch_gcp_response).and_return({
      "candidates" => [
        {
          "content" => {
            "parts" => [
              {
                "inlineData" => {
                  "mimeType" => "image/png",
                  "data" => Base64.strict_encode64(File.read("spec/fixtures/files/test_image.png"))
                }
              }
            ]
          }
        }
      ]
    })

    # Mock main_view attachment
    mask_request.main_view.attach(
      io: File.open("spec/fixtures/files/test_image.png"),
      filename: "test_image.png",
      content_type: "image/png"
    )

    mask_request.overlay.attach(
      io: File.open("spec/fixtures/files/test_image.png"),
      filename: "overlay.png",
      content_type: "image/png"
    )

    allow(mask_request).to receive(:main_view!).and_return(true)
    allow(mask_request).to receive(:rotating!).and_return(true)
    allow(mask_request).to receive(:drone!).and_return(true)
    allow(mask_request).to receive(:processed!).and_return(true)


  end

  describe "#generate_planting_guide" do
    it "calls LLM with correct prompts and saves plants" do
      # Mock the LLM response
      mock_llm_response = double("Response", content: {
        "design_features" => {
          "plants" => [
            {
              "english_name" => "Rose",
              "description" => "Red flower with detailed planting instructions...",
              "size" => "5x5 ft",
              "quantity" => 3
            }
          ],
          "other_features" => "- Fountain"
        }
      })

      mock_chat = double("Chat")
      # Mock the context object that CustomRubyLLM.context returns
      mock_context = double("Context")

      # Stub the class method to return our mock context
      allow(CustomRubyLLM).to receive(:context).and_return(mock_context)

      # Stub the chain on the mock context
      allow(mock_context).to receive_message_chain(:chat, :with_schema).and_return(mock_chat)
      allow(mock_chat).to receive(:ask).and_return(mock_llm_response)

      generator.generate_planting_guide
      mask_request.reload

      expect(mask_request.plants.count).to eq(1)
      plant = mask_request.plants.first
      expect(plant.english_name).to eq("Rose")
      # Updated expectations for new implementation
      expect(plant.description).to eq("Red flower with detailed planting instructions...")
      expect(plant.size).to eq("5x5 ft")
      expect(plant.validated).to be(true)

      expect(mask_request.mask_request_plants.first.quantity).to eq(3)
      expect(mask_request.features).to eq("- Fountain")
    end
  end
end
