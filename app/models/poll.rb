class Poll < ApplicationRecord
  belongs_to :feature
  belongs_to :user

  # Ensure a user can only poll/vote once per feature
  validates :user_id, uniqueness: { scope: :feature_id }

  # Define preferences (e.g., 1 for "Nice to have next")
  enum preference: {
    nice_to_have_next: 1
    # Add more preference levels if needed, e.g., essential: 2, low_priority: 0
  }
end
