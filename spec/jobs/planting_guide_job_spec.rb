require 'rails_helper'

RSpec.describe PlantingGuideJob, type: :job do
  let(:canva) { Canva.create!(user: User.create!(email: 'test@example.com', password: 'password', pro_engine_credits: 100, privacy_policy: true)) }
  let(:mask_request) { MaskRequest.create!(canva: canva, progress: :fetching_plant_suggestions) }

  describe "#perform" do
    it "calls DesignGenerator and broadcasts update" do
      # Mock DesignGenerator
      generator = instance_double(DesignGenerator)
      allow(DesignGenerator).to receive(:new).with(mask_request).and_return(generator)
      expect(generator).to receive(:generate_planting_guide) do
        mask_request.update(progress: :plant_suggestions_ready)
      end

      # Mock Turbo Broadcast
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        canva,
        target: "planting_guide_section",
        partial: "mask_requests/planting_guide_section",
        locals: { mask_request: mask_request }
      )

      PlantingGuideJob.perform_now(mask_request.id)

      mask_request.reload
      expect(mask_request.plant_suggestions_ready?).to be true
    end
  end
end
