class Chapter < ApplicationRecord
  has_many :subchapters, dependent: :destroy
  has_one_attached :video

  enum :progress, {
    pending: 0,
    processing: 5,
    structured: 10,
    scenes_generated: 20,
    narration_generated: 40,
    audio_generated: 60,
    image_prompts_generated: 70,
    images_generated: 80,
    stitching_scenes: 85,
    stitching_subchapter: 90,
    stitching_chapter: 95,
    completed: 100,
    failed: 500
  }, default: :pending

  after_update_commit -> { broadcast_replace_to "admin_chapters", partial: "admin/chapters/chapter", locals: { chapter: self }, target: "chapter_#{id}" }
end
