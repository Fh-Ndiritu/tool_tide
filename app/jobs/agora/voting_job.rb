# frozen_string_literal: true

module Agora
  class VotingJob < ApplicationJob
    queue_as :default

    def perform(votable)
      broadcast_system_status("🗳️ Casting Votes...")
      # 1. Gather Institutional Truth
      assembler = Agora::ContextAssemblyService.new
      context = assembler.assemble

      votes_cast = 0

      # 2. Iterate through all Agents
      AGORA_MODELS.each do |agent_config|
        agent_name = agent_config[:user_name]

        # Rule: Agents cannot vote on their own content
        next if agent_name == votable.author_agent_id

        # 3. Decide Vote via LLMClient (routes to Vertex AI or RubyLLM)
        vote_data = decide_vote(agent_config, votable, context)

        # 4. Cast Vote (if decision is valid)
        if vote_data && [ 1, -1 ].include?(vote_data["vote"])
          Agora::Vote.create!(
            votable: votable,
            voter_id: agent_name,
            voter_type_str: "Agent",
            weight: 1,
            direction: vote_data["vote"]
          )
          votes_cast += 1
          Rails.logger.info("VotingJob: #{agent_name} voted #{vote_data['vote'] > 0 ? 'UP' : 'DOWN'} on #{votable.class.name} ##{votable.id}")
        end
      end

      Rails.logger.info("VotingJob: Cast #{votes_cast} votes on #{votable.class.name} ##{votable.id}")

      # Trigger next step in pipeline (if it's a Post)
      if votable.is_a?(Agora::Post)
        Agora::DeliberationOrchestratorJob.perform_later(votable)
      end
    end

    private

    def decide_vote(agent_config, votable, context)
      agent_name = agent_config[:user_name]
      content_preview = votable.is_a?(Agora::Post) ? "#{votable.title}\n#{votable.body}" : votable.body

      # Retrieve creator's ephemeral context for fair evaluation
      root = votable.is_a?(Agora::Post) ? votable.root : votable
      creator_persona = root.persona_context.with_indifferent_access
      archetype_type = root.content_archetype
      archetype_def = CONTENT_ARCHETYPES.find { |a| a[:type] == archetype_type } || {}

      prompt = <<~PROMPT
        [SYSTEM: THOUGHTFUL EVALUATOR MODE]
        You are #{agent_name}, a content quality evaluator for the Agora Forum.
        Your mission is to fairly assess content based on its stated goals and context.

        ═══════════════════════════════════════════════════════════════
        CONTENT CONTEXT (Judge within these constraints)
        ═══════════════════════════════════════════════════════════════

        Creator's Persona: #{creator_persona[:name] || 'General'}
        - Worldview: #{creator_persona[:worldview] || 'N/A'}
        - Expected style: #{creator_persona[:pitch_style] || 'N/A'}

        Content Archetype: #{archetype_type || 'General'}
        - Goal: #{archetype_def[:goal] || 'N/A'}
        - Success criteria: #{archetype_def[:success_criteria] || 'N/A'}

        ═══════════════════════════════════════════════════════════════
        EVALUATION CRITERIA
        ═══════════════════════════════════════════════════════════════

        #{EVALUATIONS}

        ═══════════════════════════════════════════════════════════════
        BRAND CONTEXT
        ═══════════════════════════════════════════════════════════════

        #{context}

        ═══════════════════════════════════════════════════════════════
        CONTENT TO EVALUATE
        ═══════════════════════════════════════════════════════════════

        #{content_preview}

        ═══════════════════════════════════════════════════════════════
        VOTING DECISION
        ═══════════════════════════════════════════════════════════════

        PRIMARY QUESTION: Does this #{archetype_type || 'content'} STRONGLY achieve its goal of "#{archetype_def[:goal] || 'engaging the audience'}"?

        Be honest and critical. Not all content deserves a +1. Mediocre content wastes resources.

        VOTE +1 ONLY IF:
        - Content FULLY achieves its archetype goal (not just partially)
        - The hook is genuinely attention-grabbing, not generic
        - Persona voice is distinctive and consistent
        - It offers real value our audience would appreciate

        VOTE -1 IF:
        - Content only partially achieves its goal or feels half-baked
        - The hook is weak or could apply to any brand
        - Writing is generic, verbose, or unclear
        - It's off-brand or misrepresents the product

        RESPOND ONLY WITH VALID JSON:
        {
          "reason_to_fail": "main concern if voting -1, or 'None' if voting +1",
          "reason_to_win": "main strength if voting +1, or 'None' if voting -1",
          "vote": 1 or -1
        }
      PROMPT

      # Use LLMClient to route to Vertex AI or RubyLLM based on provider config
      response = Agora::LLMClient.client_for(agent_config).chat.ask(prompt)

      # Parse JSON response
      json_str = response.content.strip.gsub(/```json/i, "").gsub(/```/, "").strip
      JSON.parse(json_str)
    rescue JSON::ParserError => e
      Rails.logger.error("VotingJob JSON parse error for #{agent_name}: #{e.message}")
      Rails.logger.error("Raw response: #{response&.content&.first(200)}")
      nil
    rescue => e
      Rails.logger.error("VotingJob failed for #{agent_name}: #{e.message}")
      nil
    end
  end
end
