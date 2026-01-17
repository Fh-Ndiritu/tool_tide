class SocialPost < ApplicationRecord
  enum :status, { draft: 0, generated: 1, published: 2 }

  has_one_attached :image
  has_one_attached :performance_screenshot

  validates :platform, presence: true
end
