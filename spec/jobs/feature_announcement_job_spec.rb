require 'rails_helper'

RSpec.describe FeatureAnnouncementJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform" do
    let(:cutoff_date) { Date.new(2026, 2, 7) }

    let!(:eligible_user) do
      User.create!(
        email: "eligible@example.com",
        password: "password",
        created_at: cutoff_date - 1.day,
        privacy_policy: true
      )
    end

    let!(:new_user) do
      User.create!(
        email: "too_new@example.com",
        password: "password",
        created_at: cutoff_date + 1.day,
        privacy_policy: true
      )
    end

    let!(:existing_customer) do
      User.create!(
        email: "has_stripe@example.com",
        password: "password",
        created_at: cutoff_date - 1.day,
        stripe_customer_id: "cus_123",
        privacy_policy: true
      )
    end

    let!(:already_sent_user) do
      User.create!(
        email: "already_sent@example.com",
        password: "password",
        created_at: cutoff_date - 1.day,
        feature_announcement_sent_at: Time.current,
        privacy_policy: true
      )
    end

    it "enqueues email for eligible users only" do
      expect {
        perform_enqueued_jobs { described_class.perform_now }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      email = ActionMailer::Base.deliveries.last
      expect(email.to).to include(eligible_user.email)
      expect(email.subject).to include("Easier Payments with Stripe")

      eligible_user.reload
      expect(eligible_user.feature_announcement_sent_at).not_to be_nil
    end

    it "does not enqueue email for ineligible users" do
      described_class.perform_now

      new_user.reload
      expect(new_user.feature_announcement_sent_at).to be_nil

      existing_customer.reload
      expect(existing_customer.feature_announcement_sent_at).to be_nil
    end
  end
end
