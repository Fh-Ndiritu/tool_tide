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

      it "redirects back with alert" do
        post canva_sketch_requests_path(canva)

        expect(response).to redirect_to(canva_path(canva))
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

    it "creates/finds a result canva and redirects to new mask request path" do
      expect {
        post new_mask_request_sketch_request_path(sketch_request)
      }.to change(Canva, :count).by(1)
      # Note: MaskRequest count should NOT change until user submits form

      new_canva = Canva.order(created_at: :desc).first
      expect(response).to redirect_to(new_canva_mask_request_path(new_canva, sketch_detected: true))
    end
  end
end
