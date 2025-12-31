require 'rails_helper'

RSpec.describe "Admin::SketchRequests", type: :request do
  fixtures :users, :canvas, :sketch_requests

  let(:admin) { User.find(users(:john_doe).id) }
  let(:user) { User.find(users(:jane_doe).id) }
  let(:sketch_request) { SketchRequest.create!(user: user, canva: canvas(:one), progress: :complete) }

  before do
    admin.admin = true
    admin.save!
    sign_in admin
  end

  describe "GET /admin/sketch_requests" do
    it "renders the index template" do
      get admin_sketch_requests_path
      expect(response).to have_http_status(:success), "Expected success, got #{response.status}. Location: #{response.location}. Admin: #{admin.admin?}. ID: #{admin.id}"
    end
  end

  describe "POST /admin/sketch_requests/toggle_display" do
    it "toggles visibility of a sketch request" do
      expect(sketch_request.visibility).to eq("personal")
      post admin_sketch_requests_toggle_display_path(id: sketch_request.id), as: :turbo_stream
      expect(sketch_request.reload.visibility).to eq("everyone")
    end
  end

  describe "DELETE /admin/sketch_requests/:id" do
    context "when it is an admin request" do
      before { sketch_request.user.update!(admin: true) }

      it "destroys the sketch request" do
        expect {
          delete admin_sketch_request_path(sketch_request)
        }.to change(SketchRequest, :count).by(-1)
        expect(response).to redirect_to(admin_sketch_requests_path)
      end
    end

    context "when it is not an admin request" do
      before { sketch_request.user.update!(admin: false) }

      it "does not destroy the sketch request" do
        expect {
          delete admin_sketch_request_path(sketch_request)
        }.not_to change(SketchRequest, :count)
        expect(response).to redirect_to(admin_sketch_requests_path)
        expect(flash[:alert]).to be_present
      end
    end
  end
end
