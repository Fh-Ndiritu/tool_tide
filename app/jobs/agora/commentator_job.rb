# frozen_string_literal: true

module Agora
  class CommentatorJob < ApplicationJob
    queue_as :default

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

      prompt = <<~PROMPT
        [SYSTEM: ADVERSARIAL MODE ACTIVATED]
        You are #{agent_name}, the "Chief Marketing Skeptic" of this Think Tank.
        Your goal is NOT to be nice; it is to prevent us from wasting money on boring, safe, or "invisible" ideas.
        Your Persona: Critical, strategic, and direct.

        CONTEXT:
        #{context}

        POST TO REVIEW:
        <post>
          Title: #{post.title}
          Body: #{post.body}
        </post>

        TASK:
        You must provide a critical perspective on this idea, focus on the marketing idea not brand or branding critic:
        1. CON (Critique): A critical observation on potential risks or flaws. (MUST )
        2. PRO (Strategy): A constructive observation on why this works. This can be empty if you don't have a specific strategy.

        OUTPUT FORMAT:
        Respond with ONLY a valid JSON object:
        {
          "con": "One specific risk or flaw (Max 1 sentence)",
          "pro": "Strength which is optional, can be an empty string if you don't have a specific strategy",
        }
      PROMPT

      # Use LLMClient to route to Vertex AI or RubyLLM based on provider config
      response = Agora::LLMClient.client_for(agent_config).chat.ask(prompt)

      # Parse JSON response
      json_str = response.content.strip.gsub(/```json/i, "").gsub(/```/, "").strip
      JSON.parse(json_str)
    rescue JSON::ParserError => e
      Rails.logger.error("CommentatorJob JSON parse error for #{agent_name}: #{e.message}")
      nil
    rescue => e
      Rails.logger.error("CommentatorJob failed for #{agent_name}: #{e.message}")
      nil
    end
  end
end
