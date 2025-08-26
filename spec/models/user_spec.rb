require 'rails_helper'

RSpec.describe User, type: :model do
  fixtures :users, :credits, :landscapes, :landscape_requests

  let(:user) { users(:john_doe) }
  let(:landscape){ landscapes(:default)}
  let(:landscape_request) { landscape_requests(:bria_request) }

  before do
    # Reset credit counts before each test
    user.update!(
      free_engine_credits: 0,
      pro_engine_credits: 0,
      pro_trial_credits: 0,
      received_daily_credits: Date.yesterday
    )
  end

  describe '#state_address' do
    context 'when address is present' do
      before { user.address = { 'state' => 'CA', 'country' => 'USA' } }
      it 'returns the formatted state and country' do
        expect(user.state_address).to eq('CA, USA')
      end
    end

    context 'when address is nil' do
      before { user.address = nil }
      it 'returns an empty string' do
        expect(user.state_address).to eq('')
      end
    end
  end

  describe '#issue_daily_credits' do
    context 'when user has not received trial credits' do
      it 'issues free engine and trial credits' do
        expect { user.issue_daily_credits }
          .to change { user.credits.where(source: 'daily_issuance', credit_type: 'free_engine').count }.by(1)
          .and change { user.credits.where(source: 'trial', credit_type: 'pro_engine').count }.by(1)
      end
    end

    context 'when user has already received trial credits' do
      before { user.credits.create!(source: 'trial', amount: 10, credit_type: 'pro_engine') }
      it 'issues daily credits without affecting trial credits' do
        expect { user.issue_daily_credits }.not_to change { user.credits.where(source: 'trial', credit_type: 'pro_engine').count }
        expect { user.issue_daily_credits }.to change { user.credits.where(source: 'daily_issuance', credit_type: 'free_engine').count }.by(1)
      end
    end
  end

  describe '#received_daily_credits?' do
    context 'when user received credits today' do
      before { user.update!(received_daily_credits: Time.zone.now) }
      it 'returns true' do
        expect(user.received_daily_credits?).to be true
      end
    end

    context 'when user did not receive credits today' do
      before { user.update!(received_daily_credits: 1.day.ago) }
      it 'returns false' do
        expect(user.received_daily_credits?).to be false
      end
    end
  end

  describe '#afford_generation?' do
    context 'for Bria engine' do
      before { landscape_request.image_engine = 'bria' }
      context 'when user has enough free credits' do
        before { user.update!(free_engine_credits: 4 * BRIA_IMAGE_COST) }
        it 'returns true' do
          expect(user.afford_generation?(landscape_request)).to be true
        end
      end
      context 'when user does not have enough free credits' do
        before { user.update!(free_engine_credits: 2 * BRIA_IMAGE_COST) }
        it 'returns false' do
          expect(user.afford_generation?(landscape_request)).to be false
        end
      end
    end

    context 'for Google engine' do
      before do
        landscape_request.image_engine = 'google'
        landscape_request.use_location = false
      end
      context 'when user has enough pro credits' do
        before { user.update!(pro_engine_credits: 4 * GOOGLE_IMAGE_COST) }
        it 'returns true' do
          expect(user.afford_generation?(landscape_request)).to be true
        end
      end
      context 'when user does not have enough pro credits' do
        before { user.update!(pro_engine_credits: 2 * GOOGLE_IMAGE_COST) }
        it 'returns false' do
          expect(user.afford_generation?(landscape_request)).to be false
        end
      end
    end

    context 'for Google engine with localization' do
      before do
        landscape_request.image_engine = 'google'
        landscape_request.use_location = true
      end
      context 'when user has enough pro credits' do
        before { user.update!(pro_engine_credits: 4 * GOOGLE_IMAGE_COST + LOCALIZED_PLANT_COST) }
        it 'returns true' do
          expect(user.afford_generation?(landscape_request)).to be true
        end
      end
      context 'when user does not have enough pro credits' do
        before { user.update!(pro_engine_credits: 2 * GOOGLE_IMAGE_COST) }
        it 'returns false' do
          expect(user.afford_generation?(landscape_request)).to be false
        end
      end
    end
  end

  describe '#charge_prompt_localization?' do
    it 'deducts LOCALIZED_PLANT_COST from pro_engine_credits' do
      user.update!(pro_engine_credits: LOCALIZED_PLANT_COST + 1)
      expect { user.charge_prompt_localization? }
        .to change { user.reload.pro_engine_credits }.by(-LOCALIZED_PLANT_COST)
    end
  end

  describe '#charge_image_generation?' do
    context 'for Google engine' do
      before { landscape_request.image_engine = 'google' }
      it 'deducts GOOGLE_IMAGE_COST from pro_engine_credits' do
        user.update!(pro_engine_credits: GOOGLE_IMAGE_COST + 1)
        expect { user.charge_image_generation?(landscape_request) }
          .to change { user.reload.pro_engine_credits }.by(-GOOGLE_IMAGE_COST)
      end
    end

    context 'for Bria engine' do
      before { landscape_request.image_engine = 'bria' }
      it 'deducts BRIA_IMAGE_COST from free_engine_credits' do
        user.update!(free_engine_credits: BRIA_IMAGE_COST + 1)
        expect { user.charge_image_generation?(landscape_request) }
          .to change { user.reload.free_engine_credits }.by(-BRIA_IMAGE_COST)
      end
    end
  end
end
