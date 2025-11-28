require 'rails_helper'

RSpec.describe "mask_requests/show", type: :view do
  let(:user) { User.create!(email: "test@example.com", password: "password", password_confirmation: "password", privacy_policy: true) }
  let(:canva) { Canva.create!(user: user) }
  let(:mask_request) { MaskRequest.create!(canva: canva) }

  before do
    assign(:mask_request, mask_request)
    # Mock turbo_stream_from to avoid errors if helper is missing or needs setup
    allow(view).to receive(:turbo_stream_from).and_return("")
  end

  it "renders the GA event script when @trigger_pql_event is true" do
    assign(:trigger_pql_event, true)
    render
    expect(rendered).to include("gtag('event', 'pql_mask_request'")
  end

  it "does not render the GA event script when @trigger_pql_event is false" do
    assign(:trigger_pql_event, false)
    render
    expect(rendered).not_to include("gtag('event', 'pql_mask_request'")
  end
end
