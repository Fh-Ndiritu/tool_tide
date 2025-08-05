class Landscape < ApplicationRecord
  has_one_attached :original_image do |attachable|
    attachable.variant :final, resize_to_limit: [ 1024, 1024 ]
  end

  # this is manually resized to match the size of the browser window
  # it ensure we obtain a mask that is scaleable to match the final image variant
  has_one_attached :original_responsive_image

  # this will be resized by the image modification job, ensure resize happens for BRIA AI too
  # The mask will always be smaller than what we need
  has_one_attached :mask_image_data

  has_many :landscape_requests, dependent: :destroy


  def modified_images
    ActiveStorage::Attachment.where(record_id: landscape_requests.ids)
  end
end
