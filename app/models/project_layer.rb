class ProjectLayer < ApplicationRecord
  belongs_to :project
  belongs_to :design, counter_cache: true
  before_create :set_layer_number


  has_ancestry ancestry_format: :materialized_path

  has_one_attached :image
  has_one_attached :mask
  has_one_attached :overlay
  has_one_attached :result_image
  has_many :credit_spendings, as: :trackable

  enum :progress, {
    preparing: 0,
    main_view: 10,
    processed: 20,
    complete: 30,
    failed: 40,
    retrying: 50
  }

  enum :layer_type, {
    original: 0,
    generated: 1
  }

  validates :layer_type, presence: true

  private

  def set_layer_number
    # Assign sequential number based on existing implementation for this design
    self.layer_number = (design.project_layers.maximum(:layer_number) || 0) + 1
  end
end
