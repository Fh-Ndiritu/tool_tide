class NarrationScene < ApplicationRecord
  belongs_to :subchapter
  has_one :audio, dependent: :destroy
  has_many :image_prompts, dependent: :destroy
  has_one_attached :video
end
