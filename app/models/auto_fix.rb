class AutoFix < ApplicationRecord
  belongs_to :project_layer

  enum :status, {
    pending: 0,
    applied: 10,
    discarded: 20
  }

  validates :title, presence: true
  validates :description, presence: true
end
