require 'rails_helper'

RSpec.describe TextEditor do
  let(:user) { User.create!(email: 'test_text_service@example.com', password: 'password', pro_engine_credits: 0, privacy_policy: true) }
  let(:text_request) { TextRequest.create!(user: user, progress: :preparing) }
  let(:editor) { TextEditor.new(text_request.id) }

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

    # Mock attachments
    text_request.original_image.attach(
      io: File.open("spec/fixtures/files/test_image.png"),
      filename: "test_image.png",
      content_type: "image/png"
    )

    allow(text_request).to receive(:generating!).and_return(true)
    allow(text_request).to receive(:processed!).and_return(true)
    allow(text_request).to receive(:complete!).and_return(true)
  end

  describe "#charge_generation" do
    before do
      text_request.result_image.attach(
        io: File.open("spec/fixtures/files/test_image.png"),
        filename: "test_image.png",
        content_type: "image/png"
      )
    end

    context "when user can afford generation" do
      before do
        allow_any_instance_of(User).to receive(:afford_text_editing?).and_return(true)
      end

      it "charges the user" do
        expect_any_instance_of(User).to receive(:charge_pro_cost!)
        editor.send(:charge_generation)
      end
    end

    context "when user cannot afford generation (free edit)" do
      before do
        allow_any_instance_of(User).to receive(:afford_text_editing?).and_return(false)
      end

      it "does not charge the user" do
        expect_any_instance_of(User).not_to receive(:charge_pro_cost!)
        editor.send(:charge_generation)
      end
    end
  end
end
