class ProjectLayer < ApplicationRecord
  belongs_to :project
  belongs_to :design, counter_cache: true
  before_create :set_layer_number

  after_commit -> {
    broadcast_refresh_to [design, :layers]
    broadcast_refresh_to [project, :layers]
  }


  has_ancestry ancestry_format: :materialized_path

  has_one_attached :image
  has_one_attached :mask
  has_one_attached :overlay
  has_one_attached :result_image
  def mark_as_viewed!
    update_column(:viewed_at, Time.current) if viewed_at.nil?
  end

  def viewed?
    viewed_at.present? || original?
  end

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

  def display_image
    result_image.attached? ? result_image : image
  end

  private

  def set_layer_number
    # Assign sequential number based on existing implementation for this design
    self.layer_number = (design.project_layers.maximum(:layer_number) || 0) + 1
  end
end
