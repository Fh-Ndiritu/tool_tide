module Agora
  class Vote < ApplicationRecord
    include AgoraTable
    belongs_to :votable, polymorphic: true, touch: true

    validates :voter_id, presence: true
    validates :weight, presence: true
    validates :direction, inclusion: { in: [ -1, 1 ] }

    # Ensure a voter can only vote once per item
    validates :voter_id, uniqueness: { scope: [ :votable_type, :votable_id ] }
    validate :prevent_self_voting

    after_save :update_votable_net_score
    after_destroy :update_votable_net_score

    # Trigger broadcast on parent post after vote is saved
    after_commit :broadcast_votable_update, on: [ :create, :update ]

    private

    def prevent_self_voting
      # Schema: voter_type_str (String 'Agent' or 'Human'), voter_id (String/Int)
      return unless voter_type_str == "Agent"

      if votable.respond_to?(:author_agent_id) && votable.author_agent_id == voter_id
        errors.add(:base, "Agents cannot vote on their own content.")
      end
    end

    def update_votable_net_score
      votable.update_net_score! if votable.respond_to?(:update_net_score!)
    end

    def broadcast_votable_update
      # Touch the votable to trigger its after_update_commit broadcast
      votable.touch if votable.respond_to?(:touch)
    end
  end
end
