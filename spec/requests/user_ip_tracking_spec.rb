require 'rails_helper'

RSpec.describe "User IP Tracking", type: :request do
  let(:user) { User.create!(email: "test_ip@example.com", password: "password", password_confirmation: "password", privacy_policy: true) }

  before do
    Geocoder.configure(lookup: :test, ip_lookup: :test)
    Geocoder::Lookup::Test.add_stub(
      "1.2.3.4", [
        {
          'latitude'     => 40.7143528,
          'longitude'    => -74.0059731,
          'city'         => 'New York',
          'address'      => 'New York, NY, USA',
          'state'        => 'New York',
          'state_code'   => 'NY',
          'country'      => 'United States',
          'country_code' => 'US'
        }
      ]
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
