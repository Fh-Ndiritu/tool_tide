require 'rails_helper'

RSpec.describe MaskRequestsController, type: :controller do
  fixtures :users

  let(:user) { users(:one) }
  let(:canva) { Canva.create!(user: user, treat_as: :photo, device_width: 1024) }

  before do
    sign_in(user)
    user.update(onboarding_stage: :completed)
  end

  let(:valid_attributes) {
    {
      mask: fixture_file_upload('spec/fixtures/files/test_image.png', 'image/png'),
      device_width: 1024,
      progress: :complete,
      canva_id: canva.id,
      preset: "modern"
    }
  }

  describe "GET #index with tabs" do
    render_views

    context "when user has no sketch requests" do
      it "does not show tabs and shows mask requests" do
        mr = MaskRequest.create! valid_attributes
        mr.main_view.attach(io: StringIO.new("fake"), filename: "test.png", content_type: "image/png")
        get :index
        expect(response.body).not_to include("Sketches") # Tab not shown
        expect(response.body).to include("Design") # "Design" text is in the partial
      end
    end

  end
end
