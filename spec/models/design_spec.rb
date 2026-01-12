require 'rails_helper'

RSpec.describe Design, type: :model do
  describe 'associations' do
    it { should belong_to(:project) }
    it { should have_many(:project_layers).dependent(:destroy) }
  end

  describe 'callbacks' do
    it 'sets default title if blank' do
      design = Design.create(title: nil, project: projects(:one))
      expect(design.title).to eq('Untitled Design')
    end
  end
end
