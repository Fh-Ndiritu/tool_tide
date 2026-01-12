require 'rails_helper'

RSpec.describe AutoFixesController, type: :controller do
  fixtures :users, :projects, :designs, :project_layers

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
    let(:mock_fixes) do
      [
        { "title" => "Add Pool", "description" => "Install a pool" }
      ]
    end

    before do
      # Mock the LLM response
      mock_response = double('response', content: { "fixes" => mock_fixes })
      mock_chat = double('chat')
      mock_schema_chat = double('schema_chat')

      allow(CustomRubyLLM).to receive_message_chain(:context, :chat).and_return(mock_chat)
      allow(mock_chat).to receive(:with_schema).and_return(mock_schema_chat)
      allow(mock_schema_chat).to receive(:ask).and_return(mock_response)
    end

    it 'creates AutoFix records' do
      expect {
        post :create, params: {
          project_id: project.id,
          design_id: design.id,
          project_layer_id: project_layer.id
        }, format: :turbo_stream
      }.to change { project_layer.auto_fixes.count }.by(1)
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
