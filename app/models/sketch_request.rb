class SketchRequest < ApplicationRecord
  belongs_to :canva
  belongs_to :user

  has_one_attached :architectural_view
  has_one_attached :photorealistic_view
  has_one_attached :rotated_view

  after_update_commit :broadcast_progress, if: :saved_change_to_progress?

  enum :progress, {
    created: 0,
    processing_architectural: 10,
    processing_photorealistic: 20,
    processing_rotated: 30,
    complete: 40,
    failed: 99
  }

  def progress_before?(target_progress)
    SketchRequest.progresses[progress] < SketchRequest.progresses[target_progress.to_s]
  end

  def create_result_canva!
    source_image = photorealistic_view || rotated_view || canva.image
    source_blob = source_image.blob

    # Find existing canva for this image and user to avoid duplicates
    existing_canva = user.canvas.joins(image_attachment: :blob).find_by(active_storage_blobs: { id: source_blob.id })
    return existing_canva if existing_canva

    # Create new Canva if not found
    new_canva = Canva.create!(user: user)
    new_canva.image.attach(source_blob)
    new_canva
  end

  def purge_views
    architectural_view.purge
    photorealistic_view.purge
    rotated_view.purge
  end

  private

  def broadcast_progress
    broadcast_replace_to self
  end
end
