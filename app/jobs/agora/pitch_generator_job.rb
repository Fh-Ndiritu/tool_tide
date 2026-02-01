# frozen_string_literal: true

module Agora
  class PitchGeneratorJob < ApplicationJob
    queue_as :default

    def perform
      broadcast_system_status("🧠 Generating Pitch...")

      # 1. Assemble Full Context (Handled entirely by Service)
      assembler = Agora::ContextAssemblyService.new
      context_data = assembler.assemble_for_pitch

      unless context_data
        Rails.logger.warn("PitchGeneratorJob: No fresh trends available")
        return
      end

      # 2. Select Random Agent
      agent_config = AGORA_MODELS.sample
      author_name = agent_config[:user_name]

      prompt = <<~PROMPT
        You are #{author_name}, a participant in our Think Tank.
        Your Persona: An expert strategist who provides sharp, actionable marketing ideas.

        #{context_data}

        TASK:
        Create a high-impact marketing campaign pitch by synthesizing or leveraging these trends.

        STRATEGIC PIVOT:
        We are moving from "Learning/Experimentation" to **"MARKETING SCALE"**.
        The idea must be scalable, professional, and designed for distribution.

        SELECTION REQUIREMENTS:
        1. **Target Main Platform**: You MUST choose one (LinkedIn, Facebook, or TikTok, Instagram).
        2. **Main Media Asset**: You MUST choose one (Reel Video, Static Image, or Website Link).
        3. You have the freedom to pivot between marketing and learning but your content must be applicable to our brand.

        Requirements:
        1. Visual Hook - Describe the first 3 seconds to grab attention (for video) or the first look (for static image) or the first sentence (for website link)
        2. Target Platform - Specify where this would work best (based on selection)
        3. Reason Why - Explain why this fits our brand and the chosen channel
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
