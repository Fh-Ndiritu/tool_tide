class SocialPost < ApplicationRecord
  enum :status, { draft: 0, generated: 1, published: 2 }

  has_one_attached :image do |attachable|
    attachable.variant :preview, resize_to_limit: [200, 200]
  end

  has_one_attached :performance_screenshot do |attachable|
    attachable.variant :preview, resize_to_limit: [200, 200]
  end

  validates :platform, presence: true

  scope :images_and_previews, ->{
    includes(image_attachment: { blob: :variant_records}, performance_screenshot_attachment: { blob: :variant_records})
  }
end
