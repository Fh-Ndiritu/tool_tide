require 'rails_helper'

RSpec.describe "Geoblocking", type: :request do
  fixtures :users

  describe "GET /" do
    let(:user) { users(:john_doe) }

    before do
      sign_in user, scope: :user
    end

      context "when user is from Singapore" do
        before do
          allow(LocationService).to receive(:lookup).and_return(
            LocationService::LocationResult.new(
              country_code: "SG",
              latitude: 1.3521,
              longitude: 103.8198,
              city: "Singapore",
              region_name: "Singapore",
              country_name: "Singapore"
            )
          )
          allow(Sentry).to receive(:capture_message)
        end

        it "blocks access" do
          get root_path
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to eq("Access Forbidden")
          expect(Sentry).to have_received(:capture_message).with(/Blocked user from Singapore/, anything)
        end
      end

      context "when user is not from Singapore" do
        before do
          allow(LocationService).to receive(:lookup).and_return(
            LocationService::LocationResult.new(
              country_code: "US",
              latitude: 37.7749,
              longitude: -122.4194,
              city: "San Francisco",
              region_name: "California",
              country_name: "United States"
            )
          )
        end

        it "allows access" do
          get root_path
          # Should be successful or redirect depending on onboarding state, but definitely NOT forbidden
          expect(response).not_to have_http_status(:forbidden)
        end
      end
  end
end
