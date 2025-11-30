class Chapter < ApplicationRecord
  has_many :subchapters, dependent: :destroy
  has_one_attached :video

  def status
    return :pending if self.status.nil?

    self.status
  end
end
