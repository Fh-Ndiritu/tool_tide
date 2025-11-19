class Feature < ApplicationRecord
  # Relationships (optional: add a 'belongs_to :user' if feature submitters are tracked)
  has_many :polls, dependent: :destroy # For tracking user preferences/polling

  # Enums for Progress
  enum :progress, {
    todo: 0,
    archived: 1,
    in_progress: 2,
    next_up: 3,
    released: 4
  }

  # Scopes and Validations
  scope :delivery_trackable, -> { where(progress: [ :in_progress, :next_up, :released ]) }

  def delivery_trackable?
    in_progress? || next_up? || released?
  end

  private
end
