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
      get :show, params: { project_id: project.id, design_id: design.id, id: layer.id }
      expect(response).to be_successful
      expect(response).to render_template(:show)
    end
  end

  describe "PATCH #update" do
    it "updates the layer prompt and returns turbo stream" do
      p "SPEC DEBUG: Layer ID: #{layer.id}, Ancestry: #{layer.ancestry.inspect}"
      patch :update, params: { project_id: project.id, design_id: design.id, id: layer.id, project_layer: { prompt: "New Prompt" } }, format: :turbo_stream
      if response.status == 422
         p "SPEC DEBUG: FAILED with 422"
         layer.reload
         p "SPEC DEBUG: Reloaded Ancestry: #{layer.ancestry.inspect}"
      end
      expect(response).to be_successful
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(layer.reload.prompt).to eq("New Prompt")
    end
  end
end
