class Project < ApplicationRecord
  belongs_to :user
  belongs_to :current_design, class_name: "Design", optional: true

  has_many :designs, dependent: :destroy
  has_many :project_layers, dependent: :destroy

  validates :title, presence: true

  before_validation :set_default_title, on: :create

  private

  def set_default_title
    self.title = "Untitled Project" if title.blank?
  end
end
