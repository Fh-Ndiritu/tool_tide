# frozen_string_literal: true

module Agora
  class PitchGeneratorJob < ApplicationJob
    queue_as :default

    def perform
      broadcast_system_status("🧠 Generating Pitch...")

      # 1. Assemble Full Context (Handled entirely by Service)
      assembler = Agora::ContextAssemblyService.new
      context = assembler.assemble_for_pitch

      unless context
        Rails.logger.warn("PitchGeneratorJob: No fresh trends available")
        return
      end

      # 2. Select Random Agent
      agent_config = AGORA_MODELS.sample
      author_name = agent_config[:user_name]

      previous_accepted_ideas = Agora::Post.where(status: [ "accepted", "proceeding" ]).where(created_at: 3.days.ago..).pluck(:title).join("\n")
      previous_rejected_ideas = Agora::Post.where(status: "rejected").where(created_at: 1.week.ago..).pluck(:title).join("\n")

      prompt = <<~PROMPT
        [SYSTEM: ARCHITECT MODE ACTIVATED]
        You are #{author_name}, the Lead Strategist for Nomos Zero.
        Your mission is to engineer a marketing asset that bypasses the "Chief Skeptic" and the "Generic Trap."

        <brand_context>
          #{context}
        </brand_context>

        <historical_constraints>
          ## DO NOT REPEAT:
          #{previous_accepted_ideas}

          ## AVOID THESE REJECTION PATTERNS:
          #{previous_rejected_ideas}
        </historical_constraints>

        <evaluations_to_beat>
          #{EVALUATIONS}
        </evaluations_to_beat>

        TASK:
        Synthesize current trends into a high-velocity marketing pitch.
        We are moving to **MARKETING SCALE**. This idea must be an industrial-strength distribution engine.

        CONSTRAINTS:
        1. **Platform/Media Selection**: Choose (LinkedIn/FB/TikTok/IG) and (Video/Static/Link).
        2. **Non-Derivative Rule**: You MUST steer away from the logic of previously accepted ideas. If they were "educational," go "confrontational." If they were "polished," go "raw."
        3. **Feature-First**: Do not compete on price. Focus on the sovereign features and agentic logic of the brand.
        4. **The Delta Factor**: Identify one "Gutsy" element that makes this impossible for a competitor to copy without looking like they are chasing us.

        OUTPUT REQUIREMENTS:
        1. Visual Hook: The first 3 seconds (Video) or first sentence (Text/Link).
        2. Platform Fit: Why this specific channel?
        3. The "Nomos" Logic: Why this will survive the Stress Test Criteria.
        4. Pitch Body: ~300 words in Markdown.

        RESPOND ONLY WITH VALID JSON:
        {
          "title": "Campaign Title",
          "visual_hook": "...",
          "target_platform": "...",
          "reason_why": "...",
          "body": "Markdown body here..."
        }
      PROMPT

      # 5. Generate Pitch
      pitch_data = generate_pitch(prompt, agent_config)

      return unless pitch_data

      # 5. Publish Post
      post = Agora::Post.create!(
        author_agent_id: author_name,
        title: pitch_data["title"] || "Untitled",
        body: format_pitch_body(pitch_data),
        platform: pitch_data["target_platform"],
        status: "published",
        revision_number: 1
      )

      Rails.logger.info("PitchGeneratorJob: Created Post ##{post.id} - #{post.title}")
      broadcast_system_status("✨ Pitch Created: #{post.title.truncate(30)}")
      post
    end

    private

    def generate_pitch(prompt, agent_config)
      # Use LLMClient to route to Vertex AI or RubyLLM based on provider config
      response = Agora::LLMClient.client_for(agent_config).chat.ask(prompt)

      return nil if response.content.blank?

      # Parse JSON response (VertexAIClient already strips markdown blocks)
      JSON.parse(response.content.strip)
    rescue JSON::ParserError => e
      Rails.logger.error("PitchGeneratorJob JSON parse error: #{e.message}")
      Rails.logger.error("Raw response: #{response&.content&.first(200)}")
      nil
    rescue => e
      Rails.logger.error("PitchGeneratorJob failed: #{e.message}")
      nil
    end

    def format_pitch_body(pitch_data)
      <<~BODY
        ## 🎬 Visual Hook
        #{pitch_data['visual_hook']}

        ## 📱 Target Platform
        #{pitch_data['target_platform']}

        ## 🎯 Why This Fits Our Brand
        #{pitch_data['reason_why']}

        ---

        #{pitch_data['body']}
      BODY
    end
  end
end
