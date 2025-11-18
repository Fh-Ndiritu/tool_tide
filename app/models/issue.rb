class Issue < ApplicationRecord
  # Relationships
  belongs_to :user
  has_many :votes, as: :voteable, dependent: :destroy # Polymorphic voting

  # Enums for Progress
  enum :progress, {
    todo: 0,
    archived: 1,
    in_progress: 2,
    next_up: 3,
    released: 4
  }

  # Enums for Category (Suggested for user submission type)
  enum :category, {
    bug: 0,
    general: 1
  }

  # Scopes and Validations
  scope :delivery_trackable, -> { where(progress: [ :in_progress, :next_up, :released ]) }
  validate :delivery_date_only_for_trackable_progress

  def delivery_trackable?
    in_progress? || next_up? || released?
  end

  def vote_score
    votes.sum(:value)
  end

  def current_user_vote(user)
    votes.find_by(user: user)
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
