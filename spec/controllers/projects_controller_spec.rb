require 'rails_helper'

RSpec.describe ProjectsController, type: :controller do
  include ActionDispatch::TestProcess::FixtureFile

  let(:user) { users(:one) }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in user
  end

  describe "GET #index" do
    it "returns a success response" do
      get :index
      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    let(:file) { fixture_file_upload('uploaded_image_1768228275247.png', 'image/png') }

    it "creates a new Project, Design, and ProjectLayer" do
      expect {
        post :create, params: { image: file }
      }.to change(Project, :count).by(1)
       .and change(Design, :count).by(1)
       .and change(ProjectLayer, :count).by(1)
    end

    it "redirects to the created project" do
      post :create, params: { image: file }
      expect(response).to redirect_to(Project.last)
    end
  end
end
