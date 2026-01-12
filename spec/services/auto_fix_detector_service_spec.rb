require 'rails_helper'

RSpec.describe AutoFixDetectorService, type: :service do
  fixtures :users, :projects, :designs, :project_layers

  let(:project_layer) { project_layers(:one) }

  describe '.perform' do
    before do
      # Attach a test image to the layer
      project_layer.image.attach(
        io: File.open(Rails.root.join('spec/fixtures/files/test_image.png')),
        filename: 'test_image.png',
        content_type: 'image/png'
      )
    end

    context 'with mocked LLM response' do
      let(:mock_fixes) do
        [
          { "title" => "Add Pool", "description" => "Install a pool in the top right" },
          { "title" => "Remove Tree", "description" => "Remove the dead tree in the corner" }
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

      it 'creates AutoFix records from the LLM response' do
        expect {
          AutoFixDetectorService.perform(project_layer)
        }.to change { project_layer.auto_fixes.count }.by(2)
      end

      it 'creates fixes with pending status' do
        AutoFixDetectorService.perform(project_layer)

        fix = project_layer.auto_fixes.find_by(title: "Add Pool")
        expect(fix).to be_present
        expect(fix.status).to eq("pending")
      end
    end

    context 'when LLM fails' do
      before do
        allow(CustomRubyLLM).to receive_message_chain(:context, :chat, :with_schema, :ask).and_raise(StandardError, "LLM Error")
      end

      it 'returns an empty array on error' do
        result = AutoFixDetectorService.perform(project_layer)
        expect(result).to eq([])
      end
    end
  end
end
