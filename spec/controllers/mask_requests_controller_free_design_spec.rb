require 'rails_helper'

RSpec.describe MaskRequestsController, type: :controller do
  # fixtures :users, :canvas, :mask_requests, :credits

  let(:user) { User.create!(email: 'test_free@example.com', password: 'password', pro_engine_credits: 0, privacy_policy: true) }
  let(:canva) { Canva.create!(user: user) }

  before do
    sign_in(user)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe "Free Design Logic" do
    context "when user has 0 credits and 0 completed requests" do
      before do
        user.update!(pro_engine_credits: 0)
        user.mask_requests.destroy_all
        user.credits.destroy_all
      end

      it "allows access to new" do
        get :new, params: { canva_id: canva.id }
        expect(response).to be_successful
      end

      it "redirects to edit new request (manual)" do
        mask_request = MaskRequest.create!(canva: canva, progress: :uploading)
        get :edit, params: { id: mask_request.id, manual: true }
        expect(response).to redirect_to(edit_mask_request_path(MaskRequest.order(created_at: :desc).first))
      end
    end

    context "when user has 0 credits and 1 completed request" do
      before do
        user.update!(pro_engine_credits: 0)
        user.mask_requests.destroy_all
        user.credits.destroy_all
        MaskRequest.create!(canva: canva, progress: :complete)
      end

      it "redirects to low_credits_path on new" do
        get :new, params: { canva_id: canva.id }
        expect(response).to redirect_to(low_credits_path)
      end
    end

    context "when user has purchased credits but 0 balance" do
      before do
        user.update!(pro_engine_credits: 0)
        user.mask_requests.destroy_all
        Credit.create!(user: user, source: :purchase, credit_type: :pro_engine, amount: 10)
      end

      it "redirects to low_credits_path on new" do
        get :new, params: { canva_id: canva.id }
        expect(response).to redirect_to(low_credits_path)
      end
    end
  end
end
