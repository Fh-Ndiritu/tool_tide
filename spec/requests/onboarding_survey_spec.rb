require "rails_helper"

RSpec.describe OnboardingSurveyController, type: :request do
  let(:user) { User.create!(email: "test@example.com", password: "password", name: "Test User", privacy_policy: true) }

  before do
    host! "localhost"
    login_as(user, scope: :user)
  end

  describe "GET #show" do
    it "renders the survey page" do
      get onboarding_survey_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("To load the right tools for you")
    end
  end

  describe "PATCH #update" do
    context "with valid role" do
      it "updates the response and renders show (for next step)" do
        patch onboarding_survey_path, params: { onboarding_response: { role: "homeowner" } }
        expect(user.reload.onboarding_response.role).to eq("homeowner")
        expect(response).to have_http_status(:success)
      end
    end

    context "when completing the survey" do
      it "issues credits and renders celebrate" do
        patch onboarding_survey_path, params: {
          onboarding_response: {
            role: "homeowner",
            intent: "inspiration",
            pain_point: "visualization"
          }
        }

        expect(user.reload.onboarding_response).to be_completed
        expect(user.credits.where(source: :signup).sum(:amount)).to eq(64)
      end
    end
  end

  describe "ApplicationController enforcement" do
    it "redirects to survey if no credits and not completed" do
      get mask_requests_path
      expect(response).to redirect_to(onboarding_survey_path)
    end

    it "does not redirect if user has credits" do
      user.credits.create!(amount: 10, source: :signup, credit_type: :pro_engine)
      get mask_requests_path
      expect(response).not_to redirect_to(onboarding_survey_path)
    end
  end
end
