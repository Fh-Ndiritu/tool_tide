class AutoFix < ApplicationRecord
  belongs_to :project_layer
  has_many :project_layers, dependent: :destroy

  enum :status, {
    pending: 0,
    applied: 10,
    discarded: 20
  }

  validates :title, presence: true
  validates :description, presence: true
end
