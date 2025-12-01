class Subchapter < ApplicationRecord
  belongs_to :chapter
  has_many :narration_scenes, dependent: :destroy
  has_one_attached :video

  default_scope { order(:order) }

  enum :progress, {
    pending: 0,
    processing: 50,
    completed: 100
  }, default: :pending
end
