require 'rails_helper'

RSpec.describe ProjectsController, type: :controller do
  let(:user) { User.create!(email: "test@example.com", password: "password", privacy_policy: true) }
  let(:project) { Project.create!(user: user, title: "Test Project") }

  before do
    sign_in user
  end

  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #show" do
    it "returns http success" do
      get :show, params: { id: project.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH #update" do
    it "returns http success" do
      patch :update, params: { id: project.id, project: { title: "New Title" } }
      expect(response).to have_http_status(:success)
    end
  end
end
