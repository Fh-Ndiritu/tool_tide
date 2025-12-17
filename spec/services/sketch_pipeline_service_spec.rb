require 'rails_helper'

RSpec.describe SketchPipelineService do
  fixtures :users, :canvas

  let(:user) { users(:john_doe) }
  let(:canva) { canvas(:one) }
  let(:service) { described_class.new(canva) }

  before do
    # Ensure user has enough credits
    user.update!(pro_engine_credits: 100)
  end

  describe '#start_generation' do
    context 'when starting generation' do
      it 'creates a sketch request' do
        expect {
          service.start_generation
        }.to change(SketchRequest, :count).by(1)
      end

      it 'enqueues SketchGenerationJob' do
        expect {
          service.start_generation
        }.to have_enqueued_job(SketchGenerationJob)
      end

      it 'returns the sketch request' do
        result = service.start_generation
        expect(result).to be_a(SketchRequest)
        expect(result).to be_persisted
      end

      it 'sets the canva to treat_as sketch' do
        service.start_generation
        expect(canva.reload.treat_as).to eq('sketch')
      end
    end

    context 'when user does not have enough credits' do
      before { user.update!(pro_engine_credits: 0) }

      it 'returns nil' do
        expect(service.start_generation).to be_nil
      end

      it 'does not create a sketch request' do
        expect {
          service.start_generation
        }.not_to change(SketchRequest, :count)
      end

      it 'does not deduct credits' do
        expect {
          service.start_generation
        }.not_to change { user.reload.pro_engine_credits }
      end
    end
  end
end
