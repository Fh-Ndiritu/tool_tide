require 'rails_helper'

RSpec.describe "User IP Tracking", type: :request do
  let(:user) { User.create!(email: "test_ip@example.com", password: "password", password_confirmation: "password", privacy_policy: true) }

  before do
    allow(LocationService).to receive(:lookup).with("1.2.3.4").and_return(
      LocationService::LocationResult.new(
        latitude: 40.7143528,
        longitude: -74.0059731,
        city: 'New York',
        region_name: 'New York',
        country_name: 'United States',
        country_code: 'US'
      )
    )
  end

  it "updates current_sign_in_ip and geocodes on login" do
    post user_session_path, params: { user: { email: user.email, password: user.password } }, headers: { "REMOTE_ADDR" => "1.2.3.4" }

    user.reload
    expect(user.current_sign_in_ip.to_s).to eq("1.2.3.4")

    # Check if geocoding happened
    expect(user.latitude).to be_present
    expect(user.longitude).to be_present
    expect(user.address).to be_present
    expect(user.address['city']).to eq('New York')
  end
end
