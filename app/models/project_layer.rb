class ProjectLayer < ApplicationRecord
  belongs_to :project
  belongs_to :parent_layer, class_name: 'ProjectLayer', optional: true
  has_many :child_layers, class_name: 'ProjectLayer', foreign_key: 'parent_layer_id', dependent: :nullify

  has_one_attached :image

  enum :layer_type, {
    original: 0,
    mask: 1,
    generation: 2,
    sketch: 3
  }

  validates :layer_type, presence: true
end
