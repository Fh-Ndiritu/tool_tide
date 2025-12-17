require 'rails_helper'

RSpec.describe SketchRequest, type: :model do
  fixtures :users, :canvas

  let(:user) { users(:john_doe) }
  let(:canva) { canvas(:one) }
  let(:sketch_request) { SketchRequest.create!(user: user, canva: canva) }

  describe 'Associations' do
    it { should belong_to(:canva) }
    it { should belong_to(:user) }
    it { should have_one_attached(:architectural_view) }
    it { should have_one_attached(:photorealistic_view) }
    it { should have_one_attached(:rotated_view) }
  end

  describe '#progress_before?' do
    it 'returns true if current progress is before target' do
      sketch_request.progress = :created
      expect(sketch_request.progress_before?(:processing_architectural)).to be true
    end

    it 'returns false if current progress is at or after target' do
      sketch_request.progress = :processing_architectural
      expect(sketch_request.progress_before?(:created)).to be false
    end
  end

  describe '#create_result_canva!' do
    let(:image_blob) { create_file_blob('test_image.png', 'image/png') }

    before do
      sketch_request.photorealistic_view.attach(image_blob)
    end

    it 'creates a new canva' do
      expect {
        sketch_request.create_result_canva!
      }.to change(Canva, :count).by(1)
    end

    it 'does not create a mask request' do
      expect {
        sketch_request.create_result_canva!
      }.not_to change(MaskRequest, :count)
    end

    it 'copies the image from the source view' do
      new_canva = sketch_request.create_result_canva!
      expect(new_canva.image).to be_attached
    end

    it 'returns existing canva if exists' do
      existing = sketch_request.create_result_canva!

      expect {
        second_call = sketch_request.create_result_canva!
        expect(second_call).to eq(existing)
      }.not_to change(Canva, :count)
    end
  end

  describe '#purge_views' do
    it 'purges all attached views' do
      sketch_request.architectural_view.attach(create_file_blob('test_image.png', 'image/png'))

      sketch_request.purge_views

      expect(sketch_request.architectural_view).not_to be_attached
    end
  end
end

def create_file_blob(filename, content_type)
  path = Rails.root.join('spec/fixtures/files', filename)
  unless File.exist?(path)
    # create a dummy image if it doesn't exist
    File.open(path, 'wb') do |f|
      f.write(Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='))
    end
  end

  ActiveStorage::Blob.create_and_upload!(
    io: File.open(path),
    filename: filename,
    content_type: content_type
  )
end
