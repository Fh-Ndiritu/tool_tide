# frozen_string_literal: true

class Landscape < ApplicationRecord
  has_one_attached :original_image do |attachable|
    attachable.variant :to_process, resize_to_limit: [1024, 1024]
  end

  # this is manually resized to match the size of the browser window
  # it ensure we obtain a mask that is scaleable to match the final image variant
  has_one_attached :original_responsive_image

  has_many :landscape_requests, dependent: :destroy
  belongs_to :user

  scope :non_admin, -> { joins(:user).where(user: { admin: false }) unless Rails.env.local? }

  def display_cover
    # we can use the original image
    cover = original_image
    completed_requests = landscape_requests.complete
    if completed_requests.any?
      cover = completed_requests.last.modified_images.last
    end
    cover
  end

  def completed_requests?
    landscape_requests.complete.any?
  end

  def completed_requests
    landscape_requests.complete
  end
end
