class Chapter < ApplicationRecord
  has_many :subchapters, dependent: :destroy
  has_one_attached :video

  def status
    return :pending if read_attribute(:status).nil?

    read_attribute(:status)
  end
end
