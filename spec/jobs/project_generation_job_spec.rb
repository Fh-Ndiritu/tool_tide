require 'rails_helper'

RSpec.describe ProjectGenerationJob, type: :job do
  let(:layer){ project_layers(:one) }
  let(:design){ layer.design }
  let(:project){ design.project }
  let(:user){ project.user }

  before do
    allow(ProjectGeneratorService).to receive(:perform)
    allow(SmartFixImprover).to receive(:perform)
  end

  it "successful generation decrements credits and marks complete" do
    expect {
      ProjectGenerationJob.perform_now(layer.id)
    }.to change { user.reload.pro_engine_credits }.by(-GOOGLE_IMAGE_COST)
    .and change { CreditSpending.count }.by(1)

    expect(layer.reload.progress).to eq("complete")
    expect(CreditSpending.last.transaction_type).to eq("spend")
  end

  it "raises error if insufficient credits" do
    user.update!(pro_engine_credits: 0)
    expect {
      ProjectGenerationJob.perform_now(layer.id)
    }.to raise_error("Insufficient credits")
  end

  it "calls SmartFixImprover if ai_assist is true" do
    layer.update!(ai_assist: true)
    expect(SmartFixImprover).to receive(:perform).with(layer)
    ProjectGenerationJob.perform_now(layer.id)
  end

  # Testing logic for failure/refund is trickier because `discard_on` works with ActiveJob adapter in integration.
  # But we can verify `handle_final_failure` logic manually if we can trigger the discard callback
  # OR we mock the failure and call the handler directly.
  # For unit testing the JOB class logic, we can verify the method directly via send/public if we want, or rely on integration.
  # Let's try simulating the failure behavior by manually invoking the rescue logic if possible or trusting the logic we wrote.

  # A robust way is to specifically test `handle_final_failure` by making it public for test or sending to it.

  context "when job fails permanently" do
    before do
       # Simulate Spend first? No, the job charges inside perform.
       # If perform fails AFTER charge, we want refund.
       # So we mock Generator to fail.
       allow(ProjectGeneratorService).to receive(:perform).and_raise(StandardError, "GCP Boom")
    end

    it "refunds the user and logs failure" do
      # Note: We cannot easily test `discard_on` in RSpec unit tests without `perform_enqueued_jobs`.
      # But even `perform_enqueued_jobs` with retry might be slow.
      # We will manually invoke the failure handler to verify the FINANCIAL LOGIC is correct, assuming Rails invokes it correctly.

      # Mock the initial charge happened (or run perform and let it fail)
      # Since perform raises, the charge transaction commits before the raise?
      # NO. `charge_user!` is in transaction? Yes. but `charge_user!` is called, then `Generate` raises.
      # The `charge_user!` transaction is committed? `ActiveRecord::Base.transaction do ... end` commits if block finishes.
      # `perform` calls `charge_user!`, which finishes. Then `Generate` raises.
      # So yes, user is charged.

      # Start with 20 credits. Job starts.
      # 1. Charge -> 12 credits.
      # 2. Generator explodes. Job Raises.
      # 3. Rails catches, retries... explodes 3 times.
      # 4. Discard -> `handle_final_failure`.
      # 5. Refund -> 20 credits.

      # Test this by calling perform_now, rescuing error (since RSpec spec adapter might not suppress it),
      # and then manually calling `handle_final_failure` to prove it works given the state.

      # 1. Run Job to Charge
      expect {
        begin
          ProjectGenerationJob.perform_now(layer.id)
        rescue StandardError
        end
      }.to change { user.reload.pro_engine_credits }.by(-GOOGLE_IMAGE_COST)

      # 2. Verify Charge exists
      expect(CreditSpending.last.transaction_type).to eq("spend")

      # 3. Invoke Refund Logic manually (mimicking discard_on)
      job = ProjectGenerationJob.new(layer.id)
      job.send(:handle_final_failure, StandardError.new("Boom"))

      # 4. Verify Refund
      expect(user.reload.pro_engine_credits).to eq(20)
      expect(CreditSpending.last.transaction_type).to eq("refund")
      expect(layer.reload.progress).to eq("failed")
    end
  end
end
