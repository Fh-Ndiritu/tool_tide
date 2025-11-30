class ImagePrompt < ApplicationRecord
  belongs_to :narration_scene
  has_one_attached :image
end
