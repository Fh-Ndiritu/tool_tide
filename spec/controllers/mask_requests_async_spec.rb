require 'rails_helper'

RSpec.describe MaskRequestsController, type: :controller do
  include ActiveJob::TestHelper

  let(:user) { User.create!(email: 'test@example.com', password: 'password', pro_engine_credits: 100, privacy_policy: true) }
  let(:canva) { Canva.create!(user: user) }
  let(:mask_request) { MaskRequest.create!(canva: canva, progress: :preparing) }

  before do
    sign_in user
  end

  describe "POST #generate_planting_guide" do
    it "enqueues PlantingGuideJob and updates status" do
      expect {
        post :generate_planting_guide, params: { id: mask_request.id }, format: :turbo_stream
      }.to have_enqueued_job(PlantingGuideJob).with(mask_request.id)

      mask_request.reload
      expect(mask_request.fetching_plant_suggestions?).to be true
    end
  end
end
