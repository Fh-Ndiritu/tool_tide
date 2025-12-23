class PublicAsset < ApplicationRecord
  has_one_attached :image

  before_create :generate_uuid

  validates :image, presence: true

  private

  def generate_uuid
    self.uuid = SecureRandom.uuid
  end
end
