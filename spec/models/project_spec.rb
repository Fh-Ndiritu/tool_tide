require 'rails_helper'

RSpec.describe Project, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:designs).dependent(:destroy) }
    it { should have_many(:project_layers).dependent(:destroy) }
  end

  describe 'callbacks' do
    it 'sets default title if blank' do
      project = Project.create(title: nil, user: users(:one))
      expect(project.title).to eq('Untitled Project')
    end
  end
end
