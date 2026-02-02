module Agora
  class Post < ApplicationRecord
    include AgoraTable
    include ActionView::RecordIdentifier # For dom_id in broadcasts
    has_ancestry orphan_strategy: :rootify

    has_many :comments, foreign_key: :post_id, dependent: :destroy
    has_many :votes, as: :votable, dependent: :destroy

    validates :author_agent_id, presence: true
    validates :title, presence: true
    validates :revision_number, presence: true

    has_one :execution, class_name: "Agora::Execution", dependent: :destroy

    scope :accepted, -> { where(status: "accepted") }
    scope :proceeding, -> { where(status: "proceeding") }
    scope :rejected, -> { where(status: "rejected") }

    # Filter roots where the LATEST descendant (by revision number) has a specific status
    # If no descendants exist, check the root's own status
    # statuses can be a single status string or array of statuses
    # Uses LIKE pattern to match ALL descendants (ancestry contains root id anywhere)
    scope :by_final_status, ->(statuses) {
      statuses = Array(statuses)
      where(<<~SQL, statuses, statuses)
        (
          -- Case 1: Root has descendants, check latest descendant's status
          EXISTS (
            SELECT 1 FROM agora_posts children
            WHERE children.ancestry LIKE '%/' || agora_posts.id || '/%'
          )
          AND (
            SELECT c.status FROM agora_posts c
            WHERE c.ancestry LIKE '%/' || agora_posts.id || '/%'
            ORDER BY c.revision_number DESC
            LIMIT 1
          ) IN (?)
        )
        OR
        (
          -- Case 2: Root has no descendants, check own status
          NOT EXISTS (
            SELECT 1 FROM agora_posts children
            WHERE children.ancestry LIKE '%/' || agora_posts.id || '/%'
          )
          AND agora_posts.status IN (?)
        )
      SQL
    }

    scope :last_24_hours, -> { where("created_at > ?", 24.hours.ago) }

    # Broadcast to dashboard stream for new posts
    after_create_commit -> {
      if is_root?
        # Only prepend ROOT posts to the feed
        broadcast_prepend_to "agora_posts",
          target: "agora_feed",
          partial: "agora/posts/post_card",
          locals: { post: self }
      else
        # Revisions: update the ROOT post card to show new revision
        broadcast_replace_to "agora_posts",
          target: dom_id(root),
          partial: "agora/posts/post_card",
          locals: { post: root }
      end
      # Also update the Status HUD
      broadcast_status_hud_update
    }

    # Broadcast replace for updates (status changes, score updates)
    after_update_commit -> {
      broadcast_replace_to "agora_posts",
        target: dom_id(self),
        partial: "agora/posts/post_card",
        locals: { post: self }
      # Update HUD if status changed
      broadcast_status_hud_update if saved_change_to_status?
    }

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

    private

    def broadcast_status_hud_update
      broadcast_replace_to "agora_status_hud",
        target: "agora_status_hud",
        partial: "agora/dashboard/status_hud"
    end
  end
end
