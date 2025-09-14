class Canva < ApplicationRecord
  belongs_to :user
  has_one_attached :image
  has_many :mask_requests
end
