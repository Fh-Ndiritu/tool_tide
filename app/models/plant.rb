class Plant < ApplicationRecord
  has_many :mask_requests_plants, dependent: :destroy
  has_many :mask_requests, through: :mask_requests_plants
end
