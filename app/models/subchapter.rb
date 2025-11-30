class Subchapter < ApplicationRecord
  belongs_to :chapter
  has_many :narration_scenes, dependent: :destroy
  has_one_attached :video
end
