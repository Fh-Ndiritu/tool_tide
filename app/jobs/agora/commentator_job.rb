# frozen_string_literal: true

module Agora
  class CommentatorJob < ApplicationJob
    queue_as :low_priority

    def perform(post)
      broadcast_system_status("🗣️ Debating Idea ##{post.id}...")
      # 1. Gather Institutional Truth
      assembler = Agora::ContextAssemblyService.new
      context = assembler.assemble

      comments_created = 0

      # 2. Iterate through all Agents
      AGORA_MODELS.shuffle.each do |agent_config|
        agent_name = agent_config[:user_name]

        # Rule: Agents cannot comment on their own Post
        next if agent_name == post.author_agent_id

        # 3. Generate Comments (Pro & Con) via LLMClient
        comments_data = generate_comments(agent_config, post, context)

        # 4. Save Comments
        if comments_data
          # PRO (Strategy)
          if comments_data["pro"].present?
            Agora::Comment.create!(
              post: post,
              author_agent_id: agent_name,
              body: comments_data["pro"],
              comment_type: "strategy"
            )
            comments_created += 1
          end

          # CON (Critique)
          if comments_data["con"].present?
            Agora::Comment.create!(
              post: post,
              author_agent_id: agent_name,
              body: comments_data["con"],
              comment_type: "critique"
            )
            comments_created += 1
          end

          Rails.logger.info("CommentatorJob: #{agent_name} generated feedback for Post ##{post.id}")
        end
      end

      Rails.logger.info("CommentatorJob: Created #{comments_created} comments for Post ##{post.id}")
    end

    private

    def generate_comments(agent_config, post, context)
      agent_name = agent_config[:user_name]

      # Retrieve creator's ephemeral context for fair critique
      root = post.root
      creator_persona = root.persona_context&.with_indifferent_access || {}
      archetype_type = root.content_archetype
      archetype_def = CONTENT_ARCHETYPES.find { |a| a[:type] == archetype_type } || {}

      prompt = <<~PROMPT
        [SYSTEM: CONSTRUCTIVE FEEDBACK MODE]
        You are #{agent_name}, a content quality reviewer for the Agora Forum.
        Your goal is to provide balanced, actionable feedback that helps improve content.

        ═══════════════════════════════════════════════════════════════
        CONTENT CONTEXT
        ═══════════════════════════════════════════════════════════════

        Content Archetype: #{archetype_type || 'General'}
        - Goal: #{archetype_def[:goal] || 'N/A'}
        - Success looks like: #{archetype_def[:success_criteria] || 'N/A'}

        Creator's Persona: #{creator_persona[:name] || 'General'}
        - Their style: #{creator_persona[:pitch_style] || 'N/A'}

        ═══════════════════════════════════════════════════════════════
        BRAND CONTEXT
        ═══════════════════════════════════════════════════════════════

        #{context}

        ═══════════════════════════════════════════════════════════════
        POST TO REVIEW
        ═══════════════════════════════════════════════════════════════

        Title: #{post.title}
        Body: #{post.body}

        ═══════════════════════════════════════════════════════════════
        FEEDBACK TASK
        ═══════════════════════════════════════════════════════════════

        Evaluate this #{archetype_type || 'content'} based on its own goals:

        1. PRO (Strength): What's the strongest element? Why might this resonate?
        2. CON (Improvement): What's the weakest element? How could it be stronger?

        GUIDELINES:
        - Focus on whether content FULLY achieves its ARCHETYPE goal
        - Be constructive but honest - every piece has room to improve
        - Identify specific, actionable improvements (not vague suggestions)
        - Consider: Is the hook strong? Is the message clear? Is it fresh?

        OUTPUT FORMAT (respond with ONLY valid JSON):
        {
          "pro": "One specific strength that makes this work",
          "con": "One specific improvement that would make it better"
        }
      PROMPT

      # Use LLMClient to route to Vertex AI or RubyLLM based on provider config
      response = Agora::LLMClient.client_for(agent_config).chat.ask(prompt)

      # Parse JSON response
      json_str = response.content.strip.gsub(/```json/i, "").gsub(/```/, "").strip
      result = JSON.parse(json_str)

      # Safely handle nil/empty values - normalize to nil for empty strings
      result["pro"] = result["pro"].presence
      result["con"] = result["con"].presence

      result
    rescue JSON::ParserError => e
      Rails.logger.error("CommentatorJob JSON parse error for #{agent_name}: #{e.message}")
      nil
    rescue => e
      Rails.logger.error("CommentatorJob failed for #{agent_name}: #{e.message}")
      nil
    end
  end
end
