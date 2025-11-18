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
  validate :delivery_date_only_for_trackable_progress

  def delivery_trackable?
    in_progress? || next_up? || released?
  end

  private

  def delivery_date_only_for_trackable_progress
    unless delivery_trackable?
      if delivery_date.present?
        errors.add(:delivery_date, "cannot be set unless progress is In Progress, Next Up, or Released.")
      end
    end
  end
end
