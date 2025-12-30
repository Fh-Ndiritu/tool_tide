class Project < ApplicationRecord
  belongs_to :user
  has_many :layers, class_name: 'ProjectLayer', dependent: :destroy

  validates :title, presence: true

  enum :status, { active: 0, archived: 1 }

  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.title ||= 'Untitled Project'
    self.status ||= :active
  end
end
