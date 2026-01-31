module Agora
  class LearnedPattern < ApplicationRecord
    include AgoraTable
    belongs_to :source_execution, class_name: "Agora::Execution", optional: true

    validates :content, presence: true
    validates :pattern_type, presence: true, inclusion: { in: %w[success failure] }

    # Scopes for querying high-confidence patterns
    scope :high_confidence, -> { where("confidence >= ?", 0.8) }
    scope :successes, -> { where(pattern_type: "success") }
    scope :failures, -> { where(pattern_type: "failure") }

    def self.corporate_memory(limit: 5)
      # Return a formatted string of high-confidence patterns
      patterns = high_confidence.order(confidence: :desc).limit(limit)
      return "" if patterns.empty?

      "PREVIOUS LESSONS learned from actual market performance:\n" +
      patterns.map { |p| "- [#{p.pattern_type.upcase}] #{p.content} (Confidence: #{p.confidence})" }.join("\n")
    end
  end
end
