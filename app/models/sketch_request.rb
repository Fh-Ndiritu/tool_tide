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

  def create_mask_request!
    source_image = photorealistic_view || rotated_view || canva.image

    # We need to duplicate the blob to a new Canva
    new_canva = Canva.create!(user: user)
    new_canva.image.attach(source_image.blob)

    # Create the mask request
    new_canva.mask_requests.create!(sketch: true)
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
