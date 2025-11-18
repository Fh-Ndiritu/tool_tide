class Vote < ApplicationRecord
  belongs_to :voteable, polymorphic: true
  belongs_to :user

  # Ensure a user can only vote once per voteable item
  validates :user_id, uniqueness: { scope: [ :voteable_type, :voteable_id ] }

  # Ensure vote value is -1 (downvote) or 1 (upvote)
  validates :value, presence: true, inclusion: { in: [ -1, 1 ] }
end
