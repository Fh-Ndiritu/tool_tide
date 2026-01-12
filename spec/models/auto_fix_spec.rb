require 'rails_helper'

RSpec.describe AutoFix, type: :model do
  fixtures :users, :projects, :designs, :project_layers, :auto_fixes

  describe 'associations' do
    it { is_expected.to belong_to(:project_layer) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:description) }
  end

  describe 'enums' do
    it 'defines status enum' do
      expect(AutoFix.statuses).to eq({ "pending" => 0, "applied" => 10, "discarded" => 20 })
    end
  end

  describe 'scopes' do
    let(:pending_fix) { auto_fixes(:pending_fix) }
    let(:applied_fix) { auto_fixes(:applied_fix) }
    let(:discarded_fix) { auto_fixes(:discarded_fix) }

    it 'filters pending fixes' do
      expect(AutoFix.pending).to include(pending_fix)
      expect(AutoFix.pending).not_to include(applied_fix, discarded_fix)
    end

    it 'filters applied fixes' do
      expect(AutoFix.applied).to include(applied_fix)
      expect(AutoFix.applied).not_to include(pending_fix, discarded_fix)
    end

    it 'filters discarded fixes' do
      expect(AutoFix.discarded).to include(discarded_fix)
      expect(AutoFix.discarded).not_to include(pending_fix, applied_fix)
    end
  end

  describe '#applied!' do
    let(:fix) { auto_fixes(:pending_fix) }

    it 'marks the fix as applied' do
      expect { fix.applied! }.to change { fix.reload.status }.from('pending').to('applied')
    end
  end

  describe '#discarded!' do
    let(:fix) { auto_fixes(:pending_fix) }

    it 'marks the fix as discarded' do
      expect { fix.discarded! }.to change { fix.reload.status }.from('pending').to('discarded')
    end
  end
end
