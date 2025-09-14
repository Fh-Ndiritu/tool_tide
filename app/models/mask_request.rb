class MaskRequest < ApplicationRecord
  has_one_attached :mask
  has_many_attached :results

  has_one_attached :responsive_image

  belongs_to :canva
  delegate :image, to: :canva
end
