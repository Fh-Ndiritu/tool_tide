require 'rails_helper'

RSpec.describe SmartFixImprover do
  # Use build_stubbed or create depending on if we need DB persistence.
  # Since validatios might be involved and update! is called, better to use Create but minimize dependecies.

  let(:user) { User.create!(email: "test-#{Time.now.to_i}@example.com", password: "password", privacy_policy: true) }
  let(:project) { Project.create!(user: user, title: "Test Project") }
  let(:design) { Design.create!(project: project) }

  let(:layer) do
    ProjectLayer.create!(
      design: design,
      project: project,
      layer_type: :generated,
      generation_type: :smart_fix,
      prompt: "Original user prompt",
      progress: :processing
    )
  end

  let(:mock_response) { double("Response", content: { "optimized_prompt" => "Optimized prompt" }) }
  let(:mock_chat) { double("Chat") }
  let(:mock_context) { double("Context", chat: mock_chat) }

  before do
    # Attach a dummy overlay image since the code requires it
    # We need to mock the variant processing or just attach a file that works with variant?
    # Actually checking the code: image_context = @layer.overlay.variant(...).processed.image.blob
    # This chain will fail if we don't have real image processing or mock it.
    # Let's mock the blob retrieval to avoid complex image setup

    allow(layer).to receive_message_chain(:overlay, :variant, :processed, :image, :blob).and_return("dummy_blob")

    # Stub the LLM chain
    allow(CustomRubyLLM).to receive(:context).and_return(mock_context)
    allow(mock_chat).to receive(:with_schema).and_return(mock_chat)
    allow(mock_chat).to receive(:ask).and_return(mock_response)
  end

  describe "#optimize" do
    it "updates the prompt and saves the original prompt" do
      expect(layer.original_prompt).to be_nil
      expect(layer.prompt).to eq("Original user prompt")

      SmartFixImprover.perform(layer)

      layer.reload

      expect(layer.original_prompt).to eq("Original user prompt")
      expect(layer.prompt).to eq("Optimized prompt")
    end
  end
end
