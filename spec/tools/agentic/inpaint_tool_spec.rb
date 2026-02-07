require 'rails_helper'

RSpec.describe Agentic::InpaintTool do
  fixtures :users, :projects, :designs, :project_layers

  let(:project_layer) { project_layers(:one) }
  let(:tool) { described_class.new(project_layer) }

  before do
    # Attach a dummy image to the project layer
    project_layer.image.attach(
      io: StringIO.new("fake_image_data"),
      filename: "test.png",
      content_type: "image/png"
    )
    # Ensure user has credits for pre-charge
    project_layer.user.update!(pro_engine_credits: 100)
  end

  describe "#execute" do
    it "calls the API and returns success" do
      # Mock Faraday
      response_double = instance_double(Faraday::Response, success?: true, body: JSON.dump({
        candidates: [
          {
            content: {
              parts: [
                {
                  inlineData: {
                    mimeType: "image/png",
                    data: Base64.strict_encode64("fake_image_data")
                  }
                }
              ]
            }
          }
        ]
      }))

      conn_double = instance_double(Faraday::Connection)
      options_double = double("options")
      allow(options_double).to receive(:timeout=)

      allow(Faraday).to receive(:new).and_yield(conn_double).and_return(conn_double)
      allow(conn_double).to receive(:options).and_return(options_double)
      allow(conn_double).to receive(:post).and_return(response_double)

      # We need to manually remove the temporary file to avoid clutter or mock it
      result = tool.execute(prompt: "Test prompt")

      expect(result).to be_a(RubyLLM::Content)
      expect(result.text).to include("generated a new image")
    end
  end
end
