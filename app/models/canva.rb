class Canva < ApplicationRecord
  belongs_to :user
  has_one_attached :image
  has_many :mask_requests

  def drawable_image
    variant = image.variant(resize_to_limit: [ device_width, device_width ]).processed
    blob = variant.image.blob
    blob.analyze unless blob.analyzed?
    blob
  end
end
