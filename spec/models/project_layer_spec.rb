require 'rails_helper'

RSpec.describe ProjectLayer, type: :model do
  let(:project) { projects(:one) }
  let(:design) { designs(:one) }

  describe 'associations' do
    it { should belong_to(:project) }
    it { should belong_to(:design) }
    it { should have_one_attached(:image) }
    it { should have_one_attached(:mask) }
    it { should have_one_attached(:overlay) }
    it { should have_one_attached(:result_image) }
  end

  describe 'validations' do
    it { should validate_presence_of(:layer_type) }
  end

  describe 'callbacks' do
    it 'sets layer_number on creation' do
      layer1 = ProjectLayer.create!(project: project, design: design, layer_type: :original)
      expect(layer1.layer_number).to eq(1)

      layer2 = ProjectLayer.create!(project: project, design: design, layer_type: :generated)
      expect(layer2.layer_number).to eq(2)
    end
  end

  describe 'ancestry' do
    it 'supports nesting' do
      parent = ProjectLayer.create!(project: project, design: design, layer_type: :original)
      child = ProjectLayer.create!(project: project, design: design, parent: parent, layer_type: :generated)
      expect(child.parent).to eq(parent)
    end
  end
end

