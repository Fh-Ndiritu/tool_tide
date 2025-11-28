require 'rails_helper'

RSpec.describe MaskRequestsController, type: :controller do
  let(:user) { User.create!(email: "test@example.com", password: "password", password_confirmation: "password", privacy_policy: true) }
  let(:canva) { Canva.create!(user: user) }
  let(:mask_request) { MaskRequest.create!(canva: canva) }

  before do
    sign_in user
    allow(DesignGeneratorJob).to receive(:perform_later)
  end

  render_views

  describe "PUT #update" do
    context "when it is the first mask request" do
      it "sets the pql_event flash message" do
        put :update, params: { id: mask_request.id, generate: true, mask_request: { preset: "cottage" } }
        expect(flash[:pql_event]).to eq("true")
      end
    end

    context "when it is NOT the first mask request" do
      before do
        # Create another mask request for the same user
        MaskRequest.create!(canva: canva)
      end

      it "does NOT set the pql_event flash message" do
        put :update, params: { id: mask_request.id, generate: true, mask_request: { preset: "cottage" } }
        expect(flash[:pql_event]).to be_nil
      end
    end
  end

end
