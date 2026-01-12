require 'rails_helper'

RSpec.describe ProjectGenerationJob, type: :job do
  let(:layer){ project_layers(:one) }
  let(:design){ layer.design }
  let(:project){ design.project }
  let(:user){ project.user }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(ProjectGeneratorService).to receive(:perform)
    allow(SmartFixImprover).to receive(:perform)
    allow(ProjectOverlayGenerator).to receive(:perform).and_return(true)
  end

  after do
    ActiveJob::Base.queue_adapter = :test # Or whatever default was
  end

  let(:cost) { ProjectGenerationJob.const_get(:GOOGLE_IMAGE_COST) rescue 8 }

  it "successful generation decrements credits and marks complete" do
    user.update!(pro_engine_credits: 100)
    expect {
      ProjectGenerationJob.new.perform(layer.id)
    }.to change { user.reload.pro_engine_credits }.by(-cost)
    .and change { CreditSpending.count }.by(1)

    expect(layer.reload.progress).to eq("complete")
    expect(CreditSpending.last.transaction_type).to eq("spend")
  end

  it "raises error if insufficient credits and does not refund" do
    user.update!(pro_engine_credits: 0)
    expect {
      ProjectGenerationJob.new.perform(layer.id)
    }.to raise_error(ProjectGenerationJob::InsufficientCreditsError)

    expect(user.reload.pro_engine_credits).to eq(0)
    expect(layer.reload.progress).to eq("preparing") # Remains in initial state
  end

  it "calls SmartFixImprover if ai_assist is true" do
    user.update!(pro_engine_credits: 100)
    layer.update!(ai_assist: true)
    allow(ProjectOverlayGenerator).to receive(:perform).and_return(true)
    expect(SmartFixImprover).to receive(:perform).with(layer, has_mask: true)
    ProjectGenerationJob.new.perform(layer.id)
  end

  context "when job fails permanently" do
    before do
       user.update!(pro_engine_credits: 20)
       allow(ProjectGeneratorService).to receive(:perform).and_raise(StandardError, "GCP Boom")
       allow(ProjectOverlayGenerator).to receive(:perform).and_return(true)
    end

    it "refunds the user and logs failure" do
      # 1. Run Job - will charge then rescue the error (simulating retry exhaustion start)
      expect {
        begin
          ProjectGenerationJob.new.perform(layer.id)
        rescue StandardError
        end
      }.to change { user.reload.pro_engine_credits }.by(-cost)

      # 2. Verify Charge exists
      expect(CreditSpending.last.transaction_type).to eq("spend")

      # 3. Invoke Refund Logic manually (mimicking discard_on behavior after retries)
      job = ProjectGenerationJob.new(layer.id)
      job.send(:handle_final_failure, StandardError.new("Boom"))

      # 4. Verify Refund
      expect(user.reload.pro_engine_credits).to eq(20)
      expect(CreditSpending.last.transaction_type).to eq("refund")
      expect(layer.reload.progress).to eq("failed")
    end
  end
end
