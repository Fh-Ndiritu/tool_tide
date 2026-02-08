# frozen_string_literal: true

module Agora
  class RevisionGeneratorJob < ApplicationJob
    queue_as :default

    def perform(post_id)
      post = Agora::Post.find(post_id)
      root = post.root

      # Retrieve ephemeral context from root (maintained throughout revision cycle)
      persona = (root.persona_context || {}).with_indifferent_access
      archetype_type = root.content_archetype
      archetype = CONTENT_ARCHETYPES.find { |a| a[:type] == archetype_type } || CONTENT_ARCHETYPES.first

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
      revised_body = generate_revised_pitch(post, critiques, context, persona, archetype_type, archetype)

      unless revised_body
        Rails.logger.error("[RevisionGenerator] Failed to generate revision for Post ##{post.id}. Aborting.")
        broadcast_system_status("❌ Revision Generation Failed.")
        return
      end

      # 4. Create child post with ancestry (maintaining persona+archetype from root)
      new_post = Agora::Post.create!(
        parent: post,
        author_agent_id: post.author_agent_id,
        title: post.title, # Keep same title
        body: revised_body,
        platform: post.platform,
        status: "published",
        revision_number: post.revision_number + 1,
        persona_context: persona.to_h,
        content_archetype: archetype_type
      )

      Rails.logger.info("[RevisionGenerator] Created revision Post ##{new_post.id} (child of ##{post.id})")

      # Pipeline is triggered automatically via Post.after_create_commit -> CommentatorJob -> VotingJob -> OrchestratorJob
      # No need to call VotingJob/DeliberationOrchestratorJob explicitly here.
    end

    private

    def generate_revised_pitch(post, critiques, context, persona, archetype_type, archetype)
      previous_accepted_ideas = Agora::Post.where(status: [ "accepted", "proceeding" ]).where(created_at: 1.week.ago..).pluck(:title).join("\n")

    prompt = <<~PROMPT
      [SYSTEM: ARCHITECT OF RECONSTRUCTION ACTIVATED]
      You are the "Senior Revision Strategist" for Nomos Zero.

      [MAINTAINING PERSONA: #{persona[:name] || 'Unknown'}]
      You started with this worldview: #{persona[:worldview] || 'N/A'}
      Stay in character: #{persona[:pitch_style] || 'N/A'}

      [MAINTAINING ARCHETYPE: #{archetype_type&.upcase || 'UNKNOWN'}]
      Your goal remains: #{archetype[:goal]}
      Success criteria: #{archetype[:success_criteria]}

      The previous iteration was REJECTED by the Chief Skeptics. Your job is to engineer an evolution that is so "Gutsy" and "Differentiated" that it forces a +1 vote.

      <brand_nomos>
        #{context}
      </brand_nomos>

      <failed_iteration>
        TITLE: #{post.title}
        BODY: #{post.body}
      </failed_iteration>

      <skeptic_feedback_summary>
        #{critiques}
      </skeptic_feedback_summary>

      <market_constraints>
        ## DO NOT CLONE THESE SUCCESSES:
        #{previous_accepted_ideas}
      </market_constraints>

      TASK:
      You are not polishing a draft; you are performing a Radical Pivot.

      RECONSTRUCTION RULES:
      1. **Identify the Kill Reason**: If the feedback says "Generic," you must inject a specific, controversial, or highly technical feature of the brand that no one else can claim.
      2. **The 180-Degree Hook**: If the previous hook failed, do not edit it. DELETE it. Start with a completely different psychological angle (e.g., if it was 'Helpful,' go 'Confrontational').
      3. **Address the Generic Trap**: Add "The Delta"—a brand-specific angle that makes the pitch impossible for a competitor to copy.
      4. **Avoid the "Similarity Deadlock"**: You must diverge significantly from the failed iteration. If the Skeptics see the same idea in a different suit, they will kill it again.
      5. **Scale Logic**: Ensure the pitch remains professional and scalable for TikTok, FB, or LinkedIn as requested.

      OUTPUT REQUIREMENTS:
      - DO NOT acknowledge the feedback or mention this is a revision.
      - Produce only the refined Markdown body (~300 words).
      - The tone must be "Gutsy," authoritative, and devoid of "marketing fluff."

      [FINAL INSTRUCTION: If you don't change at least 40% of the hook and the core mechanism, this will fail. Reconstruct now.]
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
