class Landscape < ApplicationRecord
  has_one_attached :original_image
  has_one_attached :modified_image
  has_one_attached :mask_image_data
end
