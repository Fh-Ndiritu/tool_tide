class Landscape < ApplicationRecord
  has_one_attached :original_image do |attachable|
    attachable.variant :final, resize_to_fit: [1024, 1024]
  end
  has_one_attached :modified_image
  has_one_attached :mask_image_data do |attachable|
    attachable.variant :final, resize_to_fit: [1024, 1024]
  end
end
