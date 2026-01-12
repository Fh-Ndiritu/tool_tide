class Design < ApplicationRecord
  belongs_to :project
  has_many :project_layers, dependent: :destroy

  validates :title, presence: true

  before_validation :set_default_title, on: :create

  private

  def set_default_title
    self.title = "Untitled Design" if title.blank?
  end
end
