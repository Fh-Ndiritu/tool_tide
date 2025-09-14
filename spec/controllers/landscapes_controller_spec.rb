# frozen_string_literal: true

require "rails_helper"
RSpec.describe LandscapesController, type: :controller do
  fixtures(:users)
  let(:user) { users(:john_doe) }

  describe "GET #new" do
    it "issues daily credits" do
      sign_in(user)
      get :new
      user.reload
      expect(user.pro_engine_credits).to eq(0)
      expect(user.pro_trial_credits).to eq(PRO_TRIAL_CREDITS)
    end
  end
end
