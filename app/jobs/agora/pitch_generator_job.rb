# frozen_string_literal: true

module Agora
  class PitchGeneratorJob < ApplicationJob
    queue_as :default

    def perform
      broadcast_system_status("🧠 Generating Pitch...")
      # 1. Select a Fresh Trend (Random daily trend from last 24h)
      trend = Agora::Trend.where(period: "daily")
                          .where("created_at > ?", 24.hours.ago)
                          .order("RANDOM()")
                          .first

      unless trend
        Rails.logger.warn("PitchGeneratorJob: No fresh trends available")
        return
      end

      # 2. Select Random Agent from Participants (Vertex AI)
      # We filter for Vertex providers or just sample from AGORA_MODELS
      agent_config = AGORA_MODELS.sample
      author_name = agent_config[:user_name]

      # 3. Assemble Prompt
      assembler = Agora::ContextAssemblyService.new
      context = assembler.assemble

      # Fetch Corporate Memory (Learned Patterns)
      corporate_memory = Agora::LearnedPattern.corporate_memory(limit: 5)

      prompt = <<~PROMPT
        You are #{author_name}, a participant in our Think Tank.
        Your Persona: An expert strategist who provides sharp, actionable marketing ideas.

        CONTEXT:
        #{context}

        #{corporate_memory}

        TODAY'S TREND:
        Name: #{trend.content['trend_name']}
        Hook: #{trend.content['viral_hook_idea']}
        Intersection: #{trend.content['intersection_reason']}

        TASK:
        Create a marketing campaign pitch based on this trend.
        Requirements:
        1. Visual Hook - Describe the first 3 seconds to grab attention
        2. Target Platform - Specify where this would work best
        3. Reason Why - Explain why this fits our brand
        4. Full pitch body in markdown (~300 words)

        OUTPUT FORMAT:
        Respond with ONLY a valid JSON object. Do not include markdown formatting like ```json ... ``` or any introductory text.
        {
          "title": "Campaign Title",
          "visual_hook": "...",
          "target_platform": "...",
          "reason_why": "...",
          "body": "Markdown body here..."
        }
      PROMPT

      # 4. Generate with Manual JSON Parsing (since Vertex client may not support Schema)
      pitch_data = generate_pitch(prompt, agent_config)

      return unless pitch_data

      # 5. Publish Post
      post = Agora::Post.create!(
        author_agent_id: author_name,
        title: pitch_data["title"] || "Pitch: #{trend.content['trend_name']}",
        body: format_pitch_body(pitch_data),
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
