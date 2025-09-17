class Canva < ApplicationRecord
  belongs_to :user
  has_one_attached :image do |attachable|
    attachable.variant(:api_image, resize_to_limit: [ 1024, 1024 ])
  end
  has_many :mask_requests, dependent: :destroy

  def drawable_image
    variant = image.variant(resize_to_limit: [ device_width, device_width ]).processed
    blob = variant.image.blob
    blob.analyze unless blob.analyzed?
    blob
  end

  def api_image_blob
    image.variant(:api_image).processed.image.blob
  end
end
