module Agora
  class Execution < ApplicationRecord
    include AgoraTable
    belongs_to :post, class_name: "Agora::Post"
    has_one_attached :image
    has_one_attached :analytics_screenshot

    # Optional: Has many learned patterns derived from this execution
    has_many :learned_patterns, class_name: "Agora::LearnedPattern", foreign_key: :source_execution_id, dependent: :destroy

    validates :post_id, presence: true
    validates :platform, presence: true

    store_accessor :metrics, :spend, :impressions, :clicks, :roas
  end
end
