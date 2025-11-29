require 'rails_helper'

RSpec.describe "home/credits", type: :view do
  let(:user) { User.create!(email: "test@example.com", password: "password", password_confirmation: "password", privacy_policy: true) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:conversion_event, nil)
  end

  it "renders the purchase event script when @conversion_event is present" do
    assign(:conversion_event, {
      transaction_id: "test_ref_123",
      value: 10.0,
      currency: "USD",
      credits: 200
    })
    render
    expect(rendered).to include("gtag('event', 'purchase'")
    expect(rendered).to include("test_ref_123")
    expect(rendered).to include("10.0")
    expect(rendered).to include("USD")
    expect(rendered).to include("200")
  end

  it "does not render the purchase event script when @conversion_event is absent" do
    render
    expect(rendered).not_to include("gtag('event', 'purchase'")
  end
end
