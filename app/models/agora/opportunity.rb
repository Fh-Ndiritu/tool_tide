module Agora
  class Opportunity < ApplicationRecord
    include AgoraTable

    has_many :draft_responses, class_name: "Agora::DraftResponse", foreign_key: "agora_opportunity_id", dependent: :destroy

    validates :url, presence: true, uniqueness: true
    validates :platform, presence: true
    validates :status, presence: true

    enum :status, { pending: "pending", posted: "posted", dismissed: "dismissed" }, default: "pending"
    enum :platform, { reddit: "reddit", linkedin: "linkedin", facebook: "facebook", pinterest: "pinterest", instagram: "instagram" }

    scope :pending, -> { where(status: "pending") }
    scope :recent, -> { order(posted_at: :desc) }
  end
end
