# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  # Load fixtures for a clean test environment
  fixtures :users, :credits, :landscapes, :landscape_requests

  let(:user) { users(:john_doe) }
  let(:landscape) { landscapes(:default) }
  let(:landscape_request) { landscape_requests(:default) }

  before do
    # Reset credit counts before each test to ensure a predictable state
    user.update!(
      pro_engine_credits: 0,
      pro_trial_credits: 0,
      received_daily_credits: Date.yesterday
    )
  end

  describe "#state_address" do
    context "when address is present" do
      before { user.address = { "state" => "CA", "country" => "USA" } }

      it "returns the formatted state and country" do
        expect(user.state_address).to eq("CA, USA")
      end
    end

    context "when address is nil" do
      before { user.address = nil }

      it "returns an empty string" do
        expect(user.state_address).to eq("")
      end
    end
  end

  describe "#issue_daily_credits" do
    context "when user has not received trial credits" do
      it "issues free engine and trial credits" do
        expect { user.issue_daily_credits }
          .to change { user.credits.where(source: "daily_issuance", credit_type: "free_engine").count }.by(1)
          .and change { user.credits.where(source: "trial", credit_type: "pro_engine").count }.by(1)
      end
    end

    context "when user has already received trial credits" do
      before { user.credits.create!(source: "trial", amount: 10, credit_type: "pro_engine") }

      it "issues daily credits without affecting trial credits" do
        expect { user.issue_daily_credits }.not_to(change do
          user.credits.where(source: "trial", credit_type: "pro_engine").count
        end)
        expect { user.issue_daily_credits }.to change {
          user.credits.where(source: "daily_issuance", credit_type: "free_engine").count
        }.by(1)
      end
    end
  end

  describe "#received_daily_credits?" do
    context "when user received credits today" do
      before { user.update!(received_daily_credits: Time.zone.now) }

      it "returns true" do
        expect(user.received_daily_credits?).to be true
      end
    end

    context "when user did not receive credits today" do
      before { user.update!(received_daily_credits: 1.day.ago) }

      it "returns false" do
        expect(user.received_daily_credits?).to be false
      end
    end
  end

  describe "#afford_generation?" do
    context "for Google engine" do
      before do
        landscape_request.use_location = false
      end

      context "when user has enough pro credits" do
        before { user.update!(pro_engine_credits: 4 * GOOGLE_IMAGE_COST) }

        it "returns true" do
          expect(user.afford_generation?(landscape_request)).to be true
        end
      end

      context "when user does not have enough pro credits" do
        before { user.update!(pro_engine_credits: 2 * GOOGLE_IMAGE_COST) }

        it "returns false" do
          expect(user.afford_generation?(landscape_request)).to be false
        end
      end
    end

    context "for Google engine with localization" do
      before do
        landscape_request.use_location = true
      end

      context "when user has enough pro credits" do
        before { user.update!(pro_engine_credits: 4 * GOOGLE_IMAGE_COST + LOCALIZED_PLANT_COST) }

        it "returns true" do
          expect(user.afford_generation?(landscape_request)).to be true
        end
      end

      context "when user does not have enough pro credits" do
        before { user.update!(pro_engine_credits: 2 * GOOGLE_IMAGE_COST) }

        it "returns false" do
          expect(user.afford_generation?(landscape_request)).to be false
        end
      end
    end
  end

  describe "#charge_prompt_localization?" do
    it "deducts LOCALIZED_PLANT_COST from pro_engine_credits" do
      user.update!(pro_engine_credits: LOCALIZED_PLANT_COST + 1)
      expect { user.charge_prompt_localization? }
        .to change { user.reload.pro_engine_credits }.by(-LOCALIZED_PLANT_COST)
    end
  end

  describe "#charge_image_generation?" do
    context "for Google engine" do
      before do
        # Stub the `modified_images` association to return a size for the test
        allow(landscape_request).to receive_message_chain(:modified_images, :size).and_return(2)
      end

      it "deducts GOOGLE_IMAGE_COST multiplied by image count from pro credits" do
        user.update!(pro_trial_credits: GOOGLE_IMAGE_COST * 2)
        expect { user.charge_image_generation?(landscape_request) }
          .to change { user.reload.pro_trial_credits }.by(-(GOOGLE_IMAGE_COST * 2))
      end
    end
  end

  # New tests for `pro_access_credits` and `charge_pro_cost`
  describe "#pro_access_credits" do
    it "returns the sum of pro_engine and pro_trial credits" do
      user.update!(pro_engine_credits: 5, pro_trial_credits: 10)
      expect(user.pro_access_credits).to eq(15)
    end
  end

  describe "#charge_pro_cost" do
    context "when pro_trial_credits are sufficient" do
      before { user.update!(pro_trial_credits: 20, pro_engine_credits: 10) }

      it "deducts from pro_trial_credits" do
        expect { user.charge_pro_cost(15) }.to change { user.reload.pro_trial_credits }.by(-15)
        expect(user.pro_engine_credits).to eq(10)
      end
    end

    context "when pro_trial_credits are not sufficient" do
      before { user.update!(pro_trial_credits: 5, pro_engine_credits: 10) }

      it "deducts from pro_trial_credits first, then pro_engine_credits" do
        expect { user.charge_pro_cost(10) }.to change { user.reload.pro_trial_credits }.by(-5)
        expect(user.reload.pro_engine_credits).to eq(5)
      end
    end
  end

  # New test for `sufficient_pro_credits?`
  describe "#sufficient_pro_credits?" do
    context "when user has enough pro credits" do
      it "returns true" do
        user.update!(pro_engine_credits: GOOGLE_IMAGE_COST * DEFAULT_IMAGE_COUNT)
        expect(user.reload.sufficient_pro_credits?).to be true
      end
    end

    context "when user does not have enough pro credits" do
      it "returns false" do
        user.update!(pro_engine_credits: GOOGLE_IMAGE_COST * DEFAULT_IMAGE_COUNT - 1)
        expect(user.sufficient_pro_credits?).to be false
      end
    end
  end

  # New test for `schedule_downgrade_notification`
  describe "#schedule_downgrade_notification" do
    it "sets reverted_to_free_engine to true and notified_about_pro_credits to false" do
      user.update!(reverted_to_free_engine: false, notified_about_pro_credits: true)
      user.schedule_downgrade_notification
      expect(user.reverted_to_free_engine).to be true
      expect(user.notified_about_pro_credits).to be false
    end
  end
end
