# frozen_string_literal: true

module Agora
  class DeliberationOrchestratorJob < ApplicationJob
    queue_as :default

    # Accept threshold (constant): scores above 60% get accepted
    ACCEPT_THRESHOLD = 60

    # Revision threshold increment per depth (0% -> 20% -> 40% -> 60%)
    REVISION_THRESHOLD_INCREMENT = 20

    # Maximum revision depth (depths 0, 1, 2, 3 = 4 versions max)
    MAX_DEPTH = 3

    def perform(post)
      broadcast_system_status("⚖️ Analyzing Verdict...")
      post.update_net_score!

      score_pct = post.score_percentage
      depth = post.depth # 0 = original, 1 = first revision, etc.
      rejection_threshold = calculate_rejection_threshold(depth)

      Rails.logger.info(
        "[Orchestrator] Post ##{post.id} | Score: #{score_pct}% | " \
        "Depth: #{depth} | Reject: ≤#{rejection_threshold}% | Accept: >#{ACCEPT_THRESHOLD}%"
      )

      if score_pct > ACCEPT_THRESHOLD
        proceed!(post)
      elsif score_pct <= rejection_threshold || depth >= MAX_DEPTH
        # Reject if below threshold OR max revisions reached
        reject!(post)
      else
        # Borderline: needs revision
        revise!(post)
      end
    end

    private

    # Dynamic rejection threshold based on revision depth
    # Depth 0: 0%, Depth 1: 20%, Depth 2: 40%, Depth 3: 60%
    def calculate_rejection_threshold(depth)
      [ depth * REVISION_THRESHOLD_INCREMENT, ACCEPT_THRESHOLD ].min
    end

    def proceed!(post)
      Rails.logger.info("[Orchestrator] Post ##{post.id} → ACCEPTED")
      broadcast_system_status("✅ Idea Accepted! Initializing Execution...")
      post.update_column(:status, "accepted")
      Agora::CommentatorJob.perform_later(post)
      Agora::FinalPolishJob.perform_later(post.id)
    end

    def reject!(post)
      Rails.logger.info("[Orchestrator] Post ##{post.id} → REJECTED (depth: #{post.depth})")
      broadcast_system_status("❌ Idea Rejected")
      post.update_column(:status, "rejected")
      # No comments for rejected posts
    end

    def revise!(post)
      Rails.logger.info("[Orchestrator] Post ##{post.id} → NEEDS REVISION")
      broadcast_system_status("🔄 Revision Needed...")
      post.update_column(:status, "needs_revision")

      # Comments first (agents explain what needs improvement), then revision
      Agora::CommentatorJob.perform_later(post)
      Agora::RevisionGeneratorJob.perform_later(post.id)
    end
  end
end
