class TextEditor < ApplicationRecord
  belongs_to :user
  has_one_attached :original_image
  has_one_attached :result_image
end
