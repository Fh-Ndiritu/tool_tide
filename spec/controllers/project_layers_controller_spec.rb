require 'rails_helper'

RSpec.describe ProjectLayersController, type: :controller do
  let(:project) { projects(:one) }
  let(:design) { designs(:one) }
  let(:layer) { project_layers(:one) }
  let(:user) { users(:one) }

  before do
    # Ensure associations in fixtures match
    project.update(user: user)
    design.update(project: project)
    layer.update(project: project, design: design)

    @request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in user
  end

  describe "GET #show" do
    it "returns success and renders the show template" do
      get :show, params: { project_id: project.id, design_id: design.id, id: layer.id }, format: :turbo_stream
      expect(response).to be_successful
      expect(response).to render_template(:show)
    end
  end

  describe "POST #create" do
    it "creates a new layer and returns success" do
      expect {
        post :create, params: {
          project_id: project.id,
          design_id: design.id,
          parent_layer_id: layer.id,
          prompt: "New Layer",
          generation_type: "smart_fix"
        }, format: :turbo_stream
      }.to change(ProjectLayer, :count).by(1)

      expect(response).to be_successful
    end

    it "handles unexpected errors gracefully" do
      allow_any_instance_of(ProjectLayer).to receive(:save).and_raise(StandardError, "Unexpected boom")

      post :create, params: { project_id: project.id, design_id: design.id, parent_layer_id: layer.id, prompt: "New Layer" }, format: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(flash.now[:alert]).to include("Unexpected boom")
    end
  end

  describe "PATCH #update" do
    it "updates the layer prompt and returns turbo stream" do
      patch :update, params: { project_id: project.id, design_id: design.id, id: layer.id, project_layer: { prompt: "New Prompt" } }, format: :turbo_stream
      expect(response).to be_successful
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(layer.reload.prompt).to eq("New Prompt")
    end
  end
end
