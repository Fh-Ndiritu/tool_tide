class Design < ApplicationRecord
  belongs_to :project
  belongs_to :current_project_layer, class_name: "ProjectLayer", optional: true
  has_many :project_layers, dependent: :destroy

  before_destroy :nullify_current_design_in_project

  def active_layer
    current_project_layer || project_layers.complete.order(created_at: :desc).first || project_layers.original.first
  end

  after_commit -> {
    broadcast_refresh_to [project, :layers]
  }

  validates :title, presence: true

  before_validation :set_default_title, on: :create

  private

  def nullify_current_design_in_project
    if project.current_design_id == id
      project.update_columns(current_design_id: nil)
    end
  end

  def set_default_title
    self.title = "Untitled Design" if title.blank?
  end
end
