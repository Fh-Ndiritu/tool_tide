# frozen_string_literal: true

require "rails_helper"

RSpec.describe Credit, type: :model do
  fixtures(:users)
  let(:user) { users(:john_doe) }

  describe "after_create_commit" do
    context "when credit is for pro_engine and purchase source" do
      it "increments user.pro_engine_credits" do
        expect do
          described_class.create(user: user, credit_type: :pro_engine, source: :purchase, amount: 10)
        end.to change { user.reload.pro_engine_credits }.by(10)
      end
    end

    context "when credit is for pro_engine and trial source" do
      it "increments user.pro_trial_credits" do
        expect do
          described_class.create(user: user, credit_type: :pro_engine, source: :trial, amount: 5)
        end.to change { user.reload.pro_trial_credits }.by(5)
      end
    end

    context "when credit is for free_engine" do
      it "increments user.free_engine_credits" do
        expect do
          described_class.create(user: user, credit_type: :free_engine, source: :daily_issuance, amount: 1)
        end.to change { user.reload.free_engine_credits }.by(1)
      end
    end

    context "when credit is for pro_engine but not purchase or trial" do
      it "increments user.free_engine_credits" do
        expect do
          described_class.create(user: user, credit_type: :pro_engine, source: :daily_issuance, amount: 2)
        end.to change { user.reload.free_engine_credits }.by(2)
      end
    end
  end
end
