require 'rails_helper'

RSpec.describe "ProjectLayers", type: :request do
  let(:user) do
    u = User.create!(email: "test_req@example.com", password: "password", password_confirmation: "password", privacy_policy: true)
    u.credits.create!(amount: 100, credit_type: :pro_engine)
    u
  end
  let(:project) { Project.create!(title: "Test Project", user: user) }

  before do
    sign_in user
  end

  describe "POST /projects/:id/layers/generate" do
    let(:valid_params) do
      {
        prompt: "Test prompt",
        preset: "zen",
        variations: 2,
        mask_data: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
      }
    end

    it "creates generation layers with attached masks" do
      expect {
        post generate_project_layers_path(project), params: valid_params, as: :turbo_stream
      }.to change(ProjectLayer, :count).by(2) # 2 generations

      gen_layers = project.layers.where(layer_type: :generation)
      expect(gen_layers.count).to eq(2)
      expect(gen_layers.first.mask).to be_attached
    end

    it "enqueues the UnifiedGenerationJob for each variation" do
      expect {
        post generate_project_layers_path(project), params: valid_params, as: :turbo_stream
      }.to have_enqueued_job(UnifiedGenerationJob).exactly(2).times
    end

    it "deducts credits" do
      expected_cost = GOOGLE_IMAGE_COST * 2
      expect {
        post generate_project_layers_path(project), params: valid_params, as: :turbo_stream
      }.to change { user.reload.pro_engine_credits }.by(-expected_cost)
    end
  end
end
