require 'rails_helper'

RSpec.describe "canvas/new", type: :view do
  let(:user) { User.create!(email: 'test_view@example.com', password: 'password', pro_engine_credits: 0, privacy_policy: true) }
  let(:canva) { Canva.create!(user: user) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:canva, canva)
  end

  context "when user has free design available" do
    before do
      allow(user).to receive(:free_design_available?).and_return(true)
    end

    it "displays the free generation banner" do
      render
      expect(rendered).to include("First Generation Free!")
    end
  end

  context "when user does not have free design available" do
    before do
      allow(user).to receive(:free_design_available?).and_return(false)
    end

    it "does not display the free generation banner" do
      render
      expect(rendered).not_to include("First Generation Free!")
    end
  end
end
