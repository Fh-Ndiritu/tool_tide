class SketchRequest < ApplicationRecord
  belongs_to :canva

  has_one_attached :clay_view
  has_one_attached :archi_view
  has_one_attached :drone_view # Keeping 'drone_view' as the name for photorealistic to match the plan?
  # Wait, the plan said: clay_view, archi_view, photo_view.
  # But SketchGenerationJob used :drone_view for the 3rd step.
  # Let's align on the plan: photo_view. But I need to update the job then.
  # Actually, the user requirement for prompt editing on ALL views makes it easier if I stick to the plan's names?
  # The MaskRequest has main_view, rotated_view, drone_view.
  # SketchRequest: clay_view, archi_view, photo_view.

  has_one_attached :photo_view

  enum :progress, {
    created: 0,
    processing_clay: 10,
    processing_archi: 20,
    processing_photo: 30,
    complete: 40,
    failed: 99
  }

  def progress_before?(target_progress)
    SketchRequest.progresses[progress] < SketchRequest.progresses[target_progress.to_s]
  end
end
