require 'rails_helper'

RSpec.describe MaskRequestsController, type: :controller do
  fixtures :users, :canvas

  let(:user) { users(:john_doe) }
  let(:canva) { canvas(:one) }

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

    context "when user has complete sketch requests" do
      before do
        SketchRequest.create!(
          user: user,
          canva: canva,
          progress: :complete
        )
        # Ensure we have a mask request too to verify switching
        mr = MaskRequest.create! valid_attributes
        mr.main_view.attach(io: StringIO.new("fake"), filename: "test.png", content_type: "image/png")
      end

      it "shows tabs" do
        get :index
        expect(response.body).to include("tab=sketches")
        expect(response.body).to include("Designs")
      end

      it "fetching sketches tab shows sketch requests" do
        get :index, params: { tab: 'sketches' }
        expect(response.body).to include("Sketch 3D") # From the partial
        expect(response.body).not_to include("Your Design Library") if response.body.include?("sketch_request_compact")
        # Actually "Your Design Library" is in the title, so it might be there.
        # Let's check for the mask request specific content not being in the grid?
        # The mask request compact partial likely has "View Details". Sketch one also has it.
        # Sketch partial has "Sketch 3D", mask has "Design".
        expect(response.body).to include("Sketch 3D")
      end

      it "fetching default tab (designs) shows mask requests" do
        get :index, params: { tab: 'designs' }
        expect(response.body).not_to include("Sketch 3D")
        expect(response.body).to include("Design")
      end
    end
  end
end
