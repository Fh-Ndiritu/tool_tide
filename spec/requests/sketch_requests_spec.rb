require 'rails_helper'

RSpec.describe "SketchRequests", type: :request do
  fixtures :users, :canvas

  let(:user) { users(:john_doe) }
  let(:canva) { canvas(:one) }
  let(:sketch_request) { SketchRequest.create!(user: user, canva: canva) }

  before do
    sign_in user
    # Ensure user has credits for create action
    user.update!(pro_engine_credits: 100)
  end

  describe "POST /canvas/:canva_id/sketch_requests" do
    it "creates a new sketch request and redirects" do
      expect {
        post canva_sketch_requests_path(canva)
      }.to change(SketchRequest, :count).by(1)

      expect(response).to redirect_to(sketch_request_path(SketchRequest.last))
    end

    context "when generation fails (insufficient credits)" do
      before { user.update!(pro_engine_credits: 0) }

      it "redirects back to mask request or canvas with alert" do
        post canva_sketch_requests_path(canva)

        target = canva.mask_requests.last || canva
        if target.is_a?(MaskRequest)
            expect(response).to redirect_to(mask_request_path(target))
        else
            expect(response).to redirect_to(canva_path(target))
        end
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "GET /sketch_requests/:id" do
    it "renders the show template" do
      get sketch_request_path(sketch_request)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /sketch_requests/:id/new_mask_request" do
    before do
      # Attach a fake view to ensure create_mask_request! works
      sketch_request.photorealistic_view.attach(
        io: StringIO.new("fake"), filename: "test.png", content_type: "image/png"
      )
    end

    it "creates a mask request and redirects to edit" do
      expect {
        post new_mask_request_sketch_request_path(sketch_request)
      }.to change(MaskRequest, :count).by(1)

      new_mr = MaskRequest.order(created_at: :desc).first
      expect(response).to redirect_to(edit_mask_request_path(new_mr))
    end
  end
end
