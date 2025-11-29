require 'rails_helper'

RSpec.describe TextRequestsController, type: :controller do
  let(:user) { User.create!(email: 'test_text_free@example.com', password: 'password', pro_engine_credits: 0, privacy_policy: true) }

  before do
    sign_in(user)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe "Free Text Edit Logic" do
    context "when user has 0 credits and 0 completed text requests" do
      before do
        user.update!(pro_engine_credits: 0)
        user.text_requests.destroy_all
        user.credits.destroy_all
      end

      it "allows access to new" do
        blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("test"), filename: "test.png", content_type: "image/png")
        get :new, params: { signed_blob_id: blob.signed_id }
        expect(response).to redirect_to(text_requests_path(current_request: TextRequest.last.id))
      end
    end

    context "when user has 0 credits and 1 completed text request" do
      before do
        user.update!(pro_engine_credits: 0)
        user.text_requests.destroy_all
        user.credits.destroy_all
        TextRequest.create!(user: user, progress: :complete)
      end

      it "redirects to low_credits_path on new" do
        get :new
        expect(response).to redirect_to(low_credits_path)
      end
    end
  end
end
