# frozen_string_literal: true

module Agora
  class RevisionGeneratorJob < ApplicationJob
    queue_as :default

    def perform(post_id)
      post = Agora::Post.find(post_id)

      # 1. Gather critique feedback from agents
      critiques = post.comments
                      .where(comment_type: "critique")
                      .pluck(:body)
                      .join("\n\n")

      # 2. Gather context
      assembler = Agora::ContextAssemblyService.new
      context = assembler.assemble

      # Deadlock Fix: If no critiques exist (e.g., all votes were +1 strategies), force Self-Reflection
      if critiques.blank?
        Rails.logger.warn("[RevisionGenerator] No critiques found for Post ##{post.id}. Triggering Self-Reflection.")
        broadcast_system_status("🪞 Self-Reflecting on Idea ##{post.id}...")
        critiques = generate_self_reflection(post, context)
      end

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
        status: "published",
        revision_number: post.revision_number + 1
      )

      Rails.logger.info("[RevisionGenerator] Created revision Post ##{new_post.id} (child of ##{post.id})")

      # Pipeline is triggered automatically via Post.after_create_commit -> CommentatorJob -> VotingJob -> OrchestratorJob
      # No need to call VotingJob/DeliberationOrchestratorJob explicitly here.
    end

    private

    def generate_revised_pitch(post, critiques, context)
      prompt = <<~PROMPT
        You are a marketing strategist creating a pitch for our brand.

        CONTEXT:
        #{context}

        ORIGINAL PITCH:
        Title: #{post.title}
        #{post.body}

        FEEDBACK FROM REVIEWERS:
        #{critiques}

        TASK:
        Create an improved version of this pitch that addresses the reviewer feedback.
        Make the pitch more compelling, specific, and actionable.
        Keep the core idea but strengthen weak points.

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

    def generate_self_reflection(post, context)
      prompt = <<~PROMPT
        You are the "Master Strategist" holding a mirror to our own ideas.

        CONTEXT:
        #{context}

        OUR PITCH:
        Title: #{post.title}
        #{post.body}

        TASK:
        The team liked this idea, but it's not perfect yet.
        Play the role of a "Constructive Antagonist".
        Identify 3 weak points or missed opportunities in this pitch.
        Be ruthless but helpful.

        Output ONLY the critique points as a bulleted list.
      PROMPT

      agent_config = AGORA_HEAD_HUNTER
      response = Agora::LLMClient.client_for(agent_config).chat.ask(prompt)
      response.content
    rescue => e
      Rails.logger.error("[RevisionGenerator] Self-Reflection Failed: #{e.message}")
      "Focus on making the hook more visual and the call to action clearer."
    end
  end
end
