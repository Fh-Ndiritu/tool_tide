require 'rails_helper'

RSpec.describe ProjectLayersController, type: :controller do
  let(:user) { User.create!(email: "test@example.com", password: "password", pro_engine_credits: 100, privacy_policy: true) }
  let(:project) { Project.create!(title: "Test Project", user: user) }
  let(:image) { fixture_file_upload('spec/fixtures/files/test_image.png', 'image/png') }

  before do
    sign_in user
  end

  describe "POST #create" do
    context "with valid params" do
      it "creates a new layer" do
        expect {
          post :create, params: { project_id: project.id, layer: { image: image, layer_type: 'original' } }, format: :turbo_stream
        }.to change(ProjectLayer, :count).by(1)
      end

      it "returns success via Turbo Stream" do
        post :create, params: { project_id: project.id, layer: { image: image, layer_type: 'original' } }, format: :turbo_stream
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST #generate" do
    let!(:initial_layer) { ProjectLayer.create!(project: project, layer_type: 'original', image: image) }

    it "enqueues a job" do
      expect {
        post :generate, params: { project_id: project.id, prompt: "test prompt", variations: 1 }, format: :turbo_stream
      }.to have_enqueued_job(UnifiedGenerationJob)
    end

    it "creates generation layers" do
      expect {
        post :generate, params: { project_id: project.id, prompt: "test prompt", variations: 2 }, format: :turbo_stream
      }.to change(ProjectLayer, :count).by(2)
    end

    it "deducts credits" do
      user.update(pro_engine_credits: 100)
      # GOOGLE_IMAGE_COST is 8
      expect {
        post :generate, params: { project_id: project.id, prompt: "test", variations: 1 }, format: :turbo_stream
      }.to change { user.reload.pro_engine_credits }.by(-8)
    end
  end

end
