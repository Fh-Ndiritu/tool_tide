# frozen_string_literal: true

module Agora
  class RevisionGeneratorJob < ApplicationJob
    queue_as :default

    def perform(post_id)
      post = Agora::Post.find(post_id)

      # 1. Gather critique feedback from FULL ANCESTRY (Root -> Current)
      # We want to ensure we address all past feedback, not just the latest.
      # Using path_ids from ancestry gem to get all IDs in the chain.
      critiques = Agora::Comment.where(post_id: post.path_ids, comment_type: "critique")
                                .pluck(:body)
                                .join("\n\n")

      if critiques.blank?
        Rails.logger.warn("[RevisionGenerator] No critiques found for Post ancestry ##{post.id}. Aborting revision.")
        broadcast_system_status("⚠️ No critiques found for ##{post.id}. Rejected.")
        post.update!(status: "rejected")
        return
      end

      # 2. Gather context
      assembler = Agora::ContextAssemblyService.new
      context = assembler.assemble

      # 3. Generate revised pitch (blind - no mention of revision)
      revised_body = generate_revised_pitch(post, critiques, context)

      unless revised_body
        Rails.logger.error("[RevisionGenerator] Failed to generate revision for Post ##{post.id}. Aborting.")
        broadcast_system_status("❌ Revision Generation Failed.")
        return
      end

      # 4. Create child post with ancestry
      new_post = Agora::Post.create!(
        parent: post,
        author_agent_id: post.author_agent_id,
        title: post.title, # Keep same title
        body: revised_body,
        platform: post.platform,
        status: "published",
        revision_number: post.revision_number + 1
      )

      Rails.logger.info("[RevisionGenerator] Created revision Post ##{new_post.id} (child of ##{post.id})")

      # Pipeline is triggered automatically via Post.after_create_commit -> CommentatorJob -> VotingJob -> OrchestratorJob
      # No need to call VotingJob/DeliberationOrchestratorJob explicitly here.
    end

    private

    def generate_revised_pitch(post, critiques, context)
      previous_accepted_ideas = Agora::Post.where(status: [ "accepted", "proceeding" ]).where(created_at: 1.week.ago..).pluck(:title).join("\n")
      previous_rejected_ideas = Agora::Post.where(status: [ "rejected" ]).where(created_at: 3.days.ago..).pluck(:title).join("\n")

      prompt = <<~PROMPT
        You are a marketing strategist creating a pitch for our brand.

        CONTEXT:
        #{context}

        ORIGINAL PITCH:
        Title: #{post.title}
        #{post.body}

        FEEDBACK FROM REVIEWERS (Cumulative History):
        #{critiques}

        TASK:
          You are not just an editor; you are a Reconstructor.
          The previous version was REJECTED for being too safe or generic.

          1. Analyze the feedback ruthlessly.
          2. If the reviewers called it "boring," CHANGE the hook entirely.
          3. Address the "Generic Trap" by adding a brand-specific "Gutsy" angle that only this brand could pull off.
          4. DO NOT play it safe. If the feedback is harsh, the revision must be radical.
          5. Avoid ideas that are too similar to previously accepted or rejected ideas since it will be automatically rejected.

        Output ONLY the improved pitch body in markdown (~300 words).
        DO NOT mention this is a revision or reference the feedback directly.
      PROMPT

      agent_config = AGORA_HEAD_HUNTER
      retries = 0

      begin
        response = Agora::LLMClient.client_for(agent_config).chat.ask(prompt)
        response.content
      rescue => e
        retries += 1
        if retries <= 2
          Rails.logger.warn("[RevisionGenerator] Failed (Attempt #{retries}/3): #{e.message}. Retrying...")
          sleep 1
          retry
        else
          Rails.logger.error("[RevisionGenerator] Failed after 3 attempts: #{e.message}")
          nil # Return nil on failure
        end
      end
    end
  end
end
