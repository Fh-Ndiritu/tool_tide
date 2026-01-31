# frozen_string_literal: true

module Agora
  class DeliberationOrchestratorJob < ApplicationJob
    queue_as :default

    # Approval threshold (requires 4+ votes to proceed)
    APPROVAL_THRESHOLD = 4

    # Human decision threshold
    PENDING_HUMAN_THRESHOLD = 3

    def perform(post)
      broadcast_system_status("⚖️ Analyzing Verdict...")
      post.update_net_score!
      score = post.net_score
      revision_depth = post.depth # 0 = original, 1 = first revision, etc.
      rejection_threshold = calculate_rejection_threshold(revision_depth)

      Rails.logger.info("[Orchestrator] Post ##{post.id} | Score: #{score} | Depth: #{revision_depth} | Reject threshold: #{rejection_threshold}")

      if score >= APPROVAL_THRESHOLD
        proceed!(post)
      elsif score == PENDING_HUMAN_THRESHOLD
        pending_human!(post)
      elsif score <= rejection_threshold
        reject!(post)
      else
        # Borderline: needs revision
        revise!(post)
      end
    end

    private

    def calculate_rejection_threshold(depth)
      # Dynamic threshold: 0 -> 1 -> 2 -> 3 (max)
      [ depth, 3 ].min
    end

    def proceed!(post)
      Rails.logger.info("[Orchestrator] Post ##{post.id} → ACCEPTED")
      broadcast_system_status("✅ Idea Accepted! Initializing Execution...")
      post.update_column(:status, "accepted")
      Agora::FinalPolishJob.perform_later(post.id)
    end

    def pending_human!(post)
      Rails.logger.info("[Orchestrator] Post ##{post.id} → PENDING HUMAN DECISION")
      broadcast_system_status("⚠️ Pending Human Decision")
      post.update_column(:status, "pending_human")

      # Send Telegram notification
      TelegramNotifier::Dispatcher.new.dispatch(
        "🗳️ *Agora: Human Decision Required*\n\n" \
        "Post: *#{post.title}*\n" \
        "Score: #{post.net_score} (threshold: 3)\n" \
        "Revision: ##{post.depth}\n\n" \
        "Please cast your vote in the dashboard."
      )
    end

    def reject!(post)
      Rails.logger.info("[Orchestrator] Post ##{post.id} → REJECTED")
      post.update_column(:status, "rejected")
    end

    def revise!(post)
      Rails.logger.info("[Orchestrator] Post ##{post.id} → NEEDS REVISION")
      post.update_column(:status, "needs_revision")

      # Trigger revision generation
      Agora::RevisionGeneratorJob.perform_later(post.id)
    end
  end
end
