class ProjectLayer < ApplicationRecord
  belongs_to :project
  belongs_to :parent_layer, class_name: "ProjectLayer", optional: true
  has_many :child_layers, class_name: "ProjectLayer", foreign_key: "parent_layer_id", dependent: :nullify

  has_one_attached :image
  has_one_attached :mask
  has_one_attached :mask_overlay

  enum :layer_type, {
    original: 0,
    mask: 1, # Keep for backward compatibility or if strictly needed
    generation: 2,
    sketch: 3
  }, prefix: true

  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }, prefix: true

  enum :transformation_type, {
    none: 0,
    preset: 1,
    prompt: 2,
    plant_recommendation: 3,
    sketch_to_3d: 4
  }, prefix: true

  validates :layer_type, presence: true

  # Scopes
  scope :ordered, -> {
    order(Arel.sql("CASE WHEN layer_type = 0 THEN 0 ELSE 1 END ASC, created_at DESC"))
  }

  # Callbacks
  after_create_commit :enqueue_generation_job, if: :transformation?
  after_update_commit :broadcast_status_update

  def transformation?
    !transformation_type_none? || layer_type_generation?
  end

  def increment_views!
    increment!(:views_count)
  end

  private

  def enqueue_generation_job
    UnifiedGenerationJob.perform_later(self)
  end

  def broadcast_status_update
    # We broadcast a replace to the specific layer element to update its status icon or image
    broadcast_replace_to(
      "project_#{project.id}",
      target: "layer_#{id}",
      partial: "project_layers/layer",
      locals: { layer: self }
    )
  end

end
