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
    allow_any_instance_of(SketchGenerationJob).to receive(:fetch_gcp_response).and_return({
      "candidates" => [
        { "content" => { "parts" => [ { "text" => "GCP Analysis Result" } ] } }
      ]
    })
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

    it 'updates analysis' do
      perform_enqueued_jobs { described_class.perform_later(sketch_request) }

      sketch_request.reload
      expect(sketch_request.analysis).to eq("GCP Analysis Result")
    end

    it 'generates all views' do
      perform_enqueued_jobs { described_class.perform_later(sketch_request) }

      sketch_request.reload
      expect(sketch_request.architectural_view).to be_attached
      expect(sketch_request.photorealistic_view).to be_attached
      expect(sketch_request.rotated_view).to be_attached
    end

    context 'on failure' do
      # Analysis failure handling is irrelevant if analysis is disabled
    end

    context 'on generation failure' do
      before do
        allow_any_instance_of(SketchGenerationJob).to receive(:fetch_gcp_response).and_raise(StandardError.new("GCP Failed"))
      end

      it 'marks request as failed' do
        perform_enqueued_jobs { described_class.perform_later(sketch_request) }

        sketch_request.reload
        expect(sketch_request.progress).to eq("failed")
        expect(sketch_request.error_msg).to eq("GCP Failed")
        expect(sketch_request.user_error).to be_present
      end
    end
  end
end
