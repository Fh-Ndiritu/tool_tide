class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :favoritable, polymorphic: true

  scope :mask_requests, -> { where(favoritable_type: "MaskRequest") }
  scope :text_requests, -> { where(favoritable_type: "TextRequest") }
  scope :liked, -> { where(liked: true) }
  scope :disliked, -> { where(liked: false) }
end
