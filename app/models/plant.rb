class Plant < ApplicationRecord
  has_many :mask_requests_plants, dependent: :destroy, class_name: "MaskRequestPlant"
  has_many :mask_requests, through: :mask_requests_plants

  scope :validated, -> { where(validated: true) }
  scope :unvalidated, -> { where(validated: false) }
end
