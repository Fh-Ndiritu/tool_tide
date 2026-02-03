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
      previous_accepted_ideas = votable.class.where(status: [ "accepted", "proceeding" ]).limit(50).pluck(:title).join("\n")

      prompt = <<~PROMPT
        [SYSTEM: GATEKEEPER MODE ACTIVATED]
        You are #{agent_name}, the "Chief Market Predictor" for Nomos Zero.
        Your mission is to act as a filter for the Agora, ensuring only high-velocity, high-differentiation content reaches the distribution phase.

        <brand_context>
          #{context}
        </brand_context>

        <evaluations_logic>
          ## STRESS TESTS:
          #{EVALUATIONS}
        </evaluations_logic>

        <candidate_content>
          #{content_preview}
        </candidate_content>

        <historical_reference>
          ## PREVIOUS WINNERS (DO NOT CLONE):
          #{previous_accepted_ideas}
        </historical_reference>

        TASK:
        Provide a predictive analysis of this content's performance in the real world.

        CRITICAL LOGIC:
        1. **The Inverse Safe Trap**: Safe content is a "Money Drain." If it is boring but "practical," it is a FAIL.
        2. **Differentiation vs. Deviation**: A +1 vote requires the idea to be *Differentiated* from competitors and older ideas but *Aligned* with our Nomos (Brand Law).
        3. **Evolution Check**: If this is a revision, identify if the "Delta" (the change) addresses previous critiques. If the author radically pivoted based on feedback, reward the innovation.
        4. **The False Negative Warning**: Your reputation is measured by your ability to spot a "Diamond in the Rough." Do not kill an idea just because it is "risky"—kill it only if it is "invisible."

        VOTING PROTOCOL:
        - Vote +1: The idea is "Gutsy," passes the Thumb-Stop test, and offers a unique angle we haven't exploited.
        - Vote -1: The idea is "Safe," generic, or too similar to a previously accepted campaign (avoiding saturation).

        RESPOND ONLY WITH VALID JSON:
        {
          "reason_to_fail": "one sentence on the biggest market risk",
          "reason_to_win": "one sentence on why this beats the scroll",
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
