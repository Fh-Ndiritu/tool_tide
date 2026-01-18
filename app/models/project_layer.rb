class ProjectLayer < ApplicationRecord
  belongs_to :project
  belongs_to :design, counter_cache: true
  belongs_to :auto_fix, optional: true
  before_create :set_layer_number
  before_destroy :nullify_current_project_layer_in_design

  after_create_commit :analyze_image, if: -> { original? && image.attached? }

  after_commit -> {
    broadcast_refresh_to [design, :layers]
    broadcast_refresh_to [project, :layers]
  }


  has_ancestry ancestry_format: :materialized_path

  has_one_attached :image
  has_one_attached :mask
  has_one_attached :overlay
  has_one_attached :result_image

  has_many :auto_fixes, dependent: :destroy

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

  enum :generation_type, {
    not_specified: 0,
    style_preset: 10,
    smart_fix: 20,
    autofix: 30
  }

  validates :layer_type, presence: true

  validates :preset, presence: { message: "Please select a Style Preset." }, if: -> { style_preset? && generated? }
  validates :prompt, presence: { message: "Please enter a prompt for Smart Fix." }, if: -> { smart_fix? && generated? }

  def display_image
    result_image.attached? ? result_image : image
  end

  def conclusive?
    complete? || original? || failed?
  end

  private

  def set_layer_number
    # Assign sequential number based on existing implementation for this design
    self.layer_number = (design.project_layers.maximum(:layer_number) || 0) + 1
  end

  def nullify_current_project_layer_in_design
    if design.current_project_layer_id == id
      design.update_columns(current_project_layer_id: nil)
    end
  end

  def analyze_image
    SketchAnalysisJob.perform_later(self)
  end

end
