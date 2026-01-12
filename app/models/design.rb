class Design < ApplicationRecord
  belongs_to :project
  has_many :project_layers, dependent: :destroy

  before_destroy :nullify_current_design_in_project

  after_create_commit -> {
    broadcast_append_to [project, :layers],
      target: "designs_tabs",
      partial: "designs/design_tab",
      locals: { design: self, active_design: project.current_design }
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
