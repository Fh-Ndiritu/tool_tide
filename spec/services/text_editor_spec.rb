require 'rails_helper'

RSpec.describe TextEditor do
  let(:user) { User.create!(email: 'test_text_service@example.com', password: 'password', pro_engine_credits: 100, privacy_policy: true) }
  let(:text_request) { TextRequest.create!(user: user, progress: :preparing, prompt: "Add a pool") }
  let(:editor) { TextEditor.new(text_request.id) }

  before do
    # Attach original image
    text_request.original_image.attach(
      io: File.open("spec/fixtures/files/test_image.png"),
      filename: "test_image.png",
      content_type: "image/png"
    )
  end

  describe "#generate" do
    before do
      # Mock GCP calls
      allow(editor).to receive(:fetch_gcp_response).and_return({
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
    end

    context "when user has sufficient credits" do
      it "generates and attaches result image" do
        expect { editor.generate }.to change { text_request.reload.result_image.attached? }.from(false).to(true)
      end

      it "charges the user" do
        expect { editor.generate }.to change { user.reload.pro_engine_credits }.by(-GOOGLE_PRO_IMAGE_COST)
      end

      it "completes the text request" do
        editor.generate
        expect(text_request.reload.progress).to eq("complete")
      end
    end

    context "when user has insufficient credits" do
      before { user.update!(pro_engine_credits: 0) }

      it "fails the request" do
        editor.generate
        expect(text_request.reload.progress).to eq("failed")
        expect(text_request.error_msg).to include("Insufficient credits")
      end
    end
  end
end
