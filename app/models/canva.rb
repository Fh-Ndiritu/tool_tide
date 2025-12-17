class Canva < ApplicationRecord
  belongs_to :user
  has_one_attached :image do |attachable|
    attachable.variant(:api_image, resize_to_limit: [ 1024, 1024 ])
  end

  has_many :mask_requests, dependent: :destroy
  has_many :sketch_requests, dependent: :destroy

  def drawable_image
    variant = image.variant(resize_to_limit: [ device_width, nil ]).processed
    blob = variant.image.blob
    blob.analyze unless blob.analyzed?
    blob
  end

  def api_image_blob
    image.variant(:api_image).processed.image.blob
  end

  enum :treat_as, {
    photo: 0,
    sketch: 1
  }, prefix: true
end
