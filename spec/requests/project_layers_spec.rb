require 'rails_helper'

RSpec.describe "ProjectLayers", type: :request do
  let(:user) { User.create!(email: "test_#{Time.now.to_i}@example.com", password: 'password', privacy_policy: true, pro_engine_credits: 100) }
  let(:project) { user.projects.create!(title: "Test Project") }

  before do
    sign_in user
  end

  describe "POST /projects/:project_id/layers/generate" do
    let(:valid_params) do
      {
        prompt: "A beautiful garden",
        preset: "modern",
        variations: 1,
        parent_layer_id: nil
      }
    end

    it "deducts credits and enqueues job with turbo stream response" do
      expect {
        post generate_project_layers_path(project), params: valid_params, as: :turbo_stream
      }.to change { user.reload.pro_engine_credits }.by(-GOOGLE_IMAGE_COST)
      .and have_enqueued_job(UnifiedGenerationJob)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include('turbo-stream action="append" target="sidebar_layers"')
    end

    it "returns error turbo stream if insufficient credits" do
      user.update!(pro_engine_credits: 0)

      post generate_project_layers_path(project), params: valid_params, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Insufficient credits")
    end
  end
end
