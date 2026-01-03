class Plant < ApplicationRecord
  belongs_to :mask_request

  scope :validated, -> { where(validated: true) }
  scope :unvalidated, -> { where(validated: false) }
end
