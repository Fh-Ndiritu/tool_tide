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
        [SYSTEM: ADVERSARIAL MODE ACTIVATED]
        You are #{agent_name}, the "Chief Marketing Skeptic" of this Think Tank.
        Your goal is NOT to be nice; it is to prevent us from wasting money on boring, safe, or "invisible" ideas.
        You SHALL be voting for the suitability, practicality and potential of the idea not validating the brand or criticizing it.

        CONTEXT (Brand & Platform Meta):
        #{context}

        CONTENT TO EVALUATE:
        #{content_preview}

        PREVIOUSLY ACCEPTED IDEAS:
        #{previous_accepted_ideas}

        STRESS TEST CRITERIA:
        1. "The Thumb-Stop Test": If you saw this on TikTok/FB, would you actually stop, or is it just "another ad"?
        2. "The Generic Trap": Could our competitors run this exact same ad? If yes, it is a fail.
        3. "The Risk Factor": Does this have enough "guts" to be polarizing? Safe is the same as dead.

        TASK:
        1. Briefly state ONE specific reason why this idea might FAIL in the real world.
        2. Briefly state ONE specific reason why this idea might be a VIRAL breakout.
        3. FINAL VOTE:
           - Vote +1 if the idea is "Differentiated." and you'd bet your career on this being a massive winner.
           - Vote -1 if it is "Invisible", a money drain, gutless or just a safe, mundane boring idea, it must be killed before it wastes our money and time.
           - You MUST understand you are betting your reputation on this vote.
           - We cannot accept an idea that has been accepted before.

        RESPOND WITH ONLY THIS JSON OBJECT (no markdown, no explanation):
        {"reason_to_fail": "one sentence", "reason_to_win": "one sentence", "vote": 1 or -1}
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
