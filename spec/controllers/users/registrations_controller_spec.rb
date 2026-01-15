require 'rails_helper'

RSpec.describe Users::RegistrationsController, type: :controller do
  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe "POST #create" do
    let(:valid_params) do
      {
        user: {
          email: "test@example.com",
          password: "password123",
          password_confirmation: "password123",
          privacy_policy: "1"
        }
      }
    end

    context "when signing up from a desktop device" do
      it "redirects to the default onboarding path" do
        post :create, params: valid_params.deep_merge(user: { last_sign_in_device_type: 'desktop' })

        expect(response).to redirect_to(onboarding_survey_path)
        expect(User.last.last_sign_in_device_type).to eq('desktop')
      end
    end

    context "when signing up from a mobile device" do
      it "redirects to the default onboarding path" do
        post :create, params: valid_params.deep_merge(user: { last_sign_in_device_type: 'mobile' })

        # New users go to onboarding_survey, not mask_requests
        expect(response).to redirect_to(onboarding_survey_path)
        expect(User.last.last_sign_in_device_type).to eq('mobile')
      end
    end

    context "when no device type is provided" do
      it "redirects to the default onboarding path" do
        post :create, params: valid_params

        expect(response).to redirect_to(onboarding_survey_path)
        expect(User.last.last_sign_in_device_type).to be_nil
      end
    end
  end
end
