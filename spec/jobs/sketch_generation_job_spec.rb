require 'rails_helper'

RSpec.describe SketchGenerationJob, type: :job do
  include ActiveJob::TestHelper
  fixtures :users, :canvas

  let(:user) { users(:john_doe) }
  let(:canva) { canvas(:one) }
  let(:sketch_request) { SketchRequest.create!(user: user, canva: canva) }

  before do
    # Mock RubyLLM
    allow(RubyLLM).to receive_message_chain(:chat, :with_schema, :ask).and_return(
      double(content: { "response" => { "analysis" => "Test Analysis", "angle" => "Test Angle" } })
    )

    # Mock GCP Payload and Response
    allow_any_instance_of(SketchGenerationJob).to receive(:fetch_gcp_response).and_return("fake_response_data")
    allow_any_instance_of(SketchGenerationJob).to receive(:save_gcp_results).and_return(create_file_blob)

    # Ensure canva has image
    canva.image.attach(create_file_blob)
  end

  def create_file_blob
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake_image_content"),
      filename: "test.png",
      content_type: "image/png"
    )
  end

  describe '#perform' do
    it 'updates progress through stages' do
      perform_enqueued_jobs { described_class.perform_later(sketch_request) }

      sketch_request.reload
      expect(sketch_request.progress).to eq("complete")
    end

    it 'updates analysis and angle' do
      perform_enqueued_jobs { described_class.perform_later(sketch_request) }

      sketch_request.reload
      expect(sketch_request.analysis).to eq("Test Analysis")
      expect(sketch_request.recommended_angle).to eq("Test Angle")
    end

    it 'generates all 3 views' do
      perform_enqueued_jobs { described_class.perform_later(sketch_request) }

      sketch_request.reload
      expect(sketch_request.architectural_view).to be_attached
      expect(sketch_request.photorealistic_view).to be_attached
      expect(sketch_request.rotated_view).to be_attached
    end

    context 'on failure' do
      before do
        allow(RubyLLM).to receive(:chat).and_raise(StandardError.new("LLM Failed"))
      end

      it 'handles analysis failure with defaults' do
        perform_enqueued_jobs { described_class.perform_later(sketch_request) }

        sketch_request.reload
        expect(sketch_request.analysis).to be_present
        expect(sketch_request.recommended_angle).to be_present
      end
    end

    context 'on generation failure' do
      before do
        allow_any_instance_of(SketchGenerationJob).to receive(:fetch_gcp_response).and_raise(StandardError.new("GCP Failed"))
      end

      it 'marks request as failed' do
        expect(SketchPipelineService).to receive(:refund_on_failure).with(sketch_request)

        perform_enqueued_jobs { described_class.perform_later(sketch_request) }

        sketch_request.reload
        expect(sketch_request.progress).to eq("failed")
        expect(sketch_request.error_msg).to eq("GCP Failed")
      end
    end
  end
end
