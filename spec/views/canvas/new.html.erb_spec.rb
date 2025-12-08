require 'rails_helper'

RSpec.describe "canvas/new", type: :view do
  let(:user) { User.create!(email: 'test_view@example.com', password: 'password', pro_engine_credits: 0, privacy_policy: true) }
  let(:canva) { Canva.create!(user: user) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:canva, canva)
  end

  it 'displays the canvas form' do
    render
    expect(rendered).to have_selector('div[data-controller="canvas"]')
  end
end
