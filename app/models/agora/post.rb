module Agora
  class Post < ApplicationRecord
    include AgoraTable
    has_ancestry orphan_strategy: :rootify

    has_many :comments, foreign_key: :post_id, dependent: :destroy
    has_many :votes, as: :votable, dependent: :destroy

    validates :author_agent_id, presence: true
    validates :title, presence: true
    validates :revision_number, presence: true

    has_one :execution, class_name: "Agora::Execution", dependent: :destroy

    scope :accepted, -> { where(status: "accepted") }
    scope :proceeding, -> { where(status: "proceeding") }

    broadcasts_refreshes

    after_create_commit { Agora::VotingJob.perform_later(self) }

    def update_net_score!
      score = votes.sum("direction * CASE WHEN voter_type_str = 'Human' THEN 2 ELSE 1 END")
      update_column(:net_score, score)
    end

    # Calculate score as percentage of votes cast (-100% to +100%)
    # Resilient to model count changes - uses actual votes cast
    def score_percentage
      total_votes = votes.count
      return 0 if total_votes.zero?

      net = votes.sum(:direction)
      ((net.to_f / total_votes) * 100).round
    end
  end
end
