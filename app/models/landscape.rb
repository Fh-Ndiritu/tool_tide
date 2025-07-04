class Landscape < ApplicationRecord
  has_one_attached :original_image
  has_one_attached :landscaped_image
  has_one_attached :image_mask
end
