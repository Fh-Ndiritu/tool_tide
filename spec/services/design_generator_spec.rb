require 'rails_helper'

RSpec.describe DesignGenerator do
  # fixtures :users, :canvas, :mask_requests, :credits

  let(:user) { User.create!(email: 'test_service@example.com', password: 'password', pro_engine_credits: 0, privacy_policy: true) }
  let(:canva) { Canva.create!(user: user) }
  let(:mask_request) { MaskRequest.create!(canva: canva, progress: :preparing) }
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

    allow(mask_request).to receive(:main_view!).and_return(true)
    allow(mask_request).to receive(:rotating!).and_return(true)
    allow(mask_request).to receive(:drone!).and_return(true)
    allow(mask_request).to receive(:processed!).and_return(true)

    # Mock rotate_view and drone_view to do nothing or mock their internals if called
    allow(generator).to receive(:rotate_view)
    allow(generator).to receive(:drone_view)
  end

  describe "#generate_secondary_views" do
    context "when user can afford generation" do
      before do
        allow(user).to receive(:afford_generation?).and_return(true)
      end

      it "calls standard view generation methods" do
        expect(generator).to receive(:rotate_view)
        expect(generator).to receive(:drone_view)
        expect(generator).not_to receive(:generate_premium_locked_views)

        generator.send(:generate_secondary_views)
      end
    end

    context "when user cannot afford generation (free design)" do
      before do
        allow(user).to receive(:afford_generation?).and_return(false)
      end

      it "calls generate_premium_locked_views" do
        expect(generator).not_to receive(:rotate_view)
        expect(generator).not_to receive(:drone_view)
        expect(generator).to receive(:generate_premium_locked_views)

        generator.send(:generate_secondary_views)
      end
    end
  end

  describe "#generate_premium_locked_views" do
    it "creates watermarked views" do
      expect(generator).to receive(:create_watermarked_view).with(:rotated_view)
      expect(generator).to receive(:create_watermarked_view).with(:drone_view)

      generator.send(:generate_premium_locked_views)
    end
  end
end
