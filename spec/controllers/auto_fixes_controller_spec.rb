require 'rails_helper'

RSpec.describe AutoFixesController, type: :controller do
  fixtures :users, :projects, :designs, :project_layers, :auto_fixes

  let(:user) { users(:one) }
  let(:project) { projects(:one) }
  let(:design) { designs(:one) }
  let(:project_layer) { project_layers(:one) }

  before do
    sign_in user

    # Attach a test image to the layer
    project_layer.image.attach(
      io: File.open(Rails.root.join('spec/fixtures/files/test_image.png')),
      filename: 'test_image.png',
      content_type: 'image/png'
    )
  end

  describe 'POST #create' do
    it 'creates AutoFix records and calls the service' do
      # Verify the service is called and create the fix when it is
      expect(AutoFixDetectorService).to receive(:perform).with(kind_of(ProjectLayer)) do |layer|
        layer.auto_fixes.create!(
          title: "Add Pool",
          description: "Install a pool",
          status: :pending
        )
      end

      post :create, params: {
        project_id: project.id,
        design_id: design.id,
        project_layer_id: project_layer.id
      }, format: :turbo_stream

      # Controller clears pending fixes, then creates new ones via service
      # Check that our new fix was created (not count, which includes fixture data)
      expect(AutoFix.find_by(title: "Add Pool", project_layer_id: project_layer.id)).to be_present
    end

    it 'responds successfully' do
      post :create, params: {
        project_id: project.id,
        design_id: design.id,
        project_layer_id: project_layer.id
      }, format: :turbo_stream

      expect(response).to be_successful
    end
  end
end
