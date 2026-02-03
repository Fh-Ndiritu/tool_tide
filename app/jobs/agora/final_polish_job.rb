module Agora
  class FinalPolishJob < ApplicationJob
    queue_as :default

    def perform(post_id)
      post = Agora::Post.find(post_id)

      # 1. Gather Institutional Truth
      assembler = Agora::ContextAssemblyService.new
      context = assembler.assemble

      # 2. Generate Implementation Brief
      brief = generate_brief(post, context)

      # 3. Store as Admin Notes (or a separate artifact, but admin_notes works for now)
      # We create an Execution record to hold this "Plan" even before metrics come in.
      # 4. Create Execution record with structured data
      execution = Agora::Execution.create!(
        post: post,
        platform: post.platform.presence || extract_platform(post.body),
        video_prompt: brief["video_prompt"],
        image_prompt: brief["image_prompt"],
        tiktok_text: brief["tiktok_text"],
        facebook_text: brief["facebook_text"],
        linkedin_text: brief["linkedin_text"],
        admin_notes: brief["admin_notes"],
        executed_at: Time.current
      )

      # Automatically trigger image generation if we have a prompt
      if execution.image_prompt.present?
        Agora::ExecutionImageGenerationJob.perform_later(execution.id)
      end

      broadcast_system_status("🚀 Execution ##{execution.id} Created & Image Generation Queued!")

      post.update!(status: "proceeding")
    rescue StandardError => e
      Rails.logger.error("FinalPolishJob failed: #{e.message}")
      "Failed to generate brief: #{e.message}"
    end

    private

    # Schema for Final Implementation Brief
    class BriefSchema < RubyLLM::Schema
      object :result do
        string :video_prompt, description: "A detailed prompt to generate a high-quality video for this campaign"
        string :image_prompt, description: "A detailed prompt to generate a high-quality image for this campaign"
        string :tiktok_text, description: "Optimized caption and hashtags for TikTok"
        string :facebook_text, description: "Optimized ad markdown copy for Facebook"
        string :linkedin_text, description: "Professional yet engaging post markdown text for LinkedIn"
        string :admin_notes, description: "Additional strategic notes for the execution team"
      end
    end

    def generate_brief(post, context)
      # Fetch website link from brand context if available
      website_context = Agora::BrandContext.find_by(key: "website.md")
      website_url = website_context&.metadata&.dig("origin_url") || "our website"

      prompt = <<~PROMPT
        You are the "Execution Lead" for the Agora Forum.

        CONTEXT:
        #{context}
        Website Link: #{website_url}

        ACCEPTED IDEA:
        Title: #{post.title}
        Body: #{post.body}

        TASK:
        Analyze this idea carefully.
        1. If it involves video, write a specific prompt for video generation and avoid try to show too many banners or text in the video which leads to poor quality .
        2. If it involves static images, write a specific prompt that can be used for image generation.
        3. Write optimized post markdown text for **TikTok**, **Facebook**, **LinkedIn** and **Instagram**.

        REQUIREMENTS:
        - Think deeply about the platform nuances (TikTok is casual/viral, LinkedIn is professional).
        - Ensure the asset prompts are highly descriptive and visual.
        - content must vary appropriately across platforms and avoid being superfluous.
        - ALL videos and IMAGES must aim for realistic, high quality, 4k resolution and professional resolution.

        Carefully review your prompts and text before returning a response
        Output strictly using the provided schema.
      PROMPT

      # Use RubyLLM for structured output as requested
      response = CustomRubyLLM.context.chat.with_schema(BriefSchema).ask(prompt)
      result = response.content["result"]

      result = response.content["result"]

      # Return the hash directly so we can access individual fields
      result
    rescue => e
      Rails.logger.error("FinalPolishJob failed: #{e.message}")
      "Failed to generate brief: #{e.message}"
    end

    def extract_platform(body)
      # Naive extraction or default
      if body.match?(/TikTok/i)
        "TikTok"
      elsif body.match?(/Facebook|Meta/i)
        "Facebook"
      elsif body.match?(/Instagram/i)
        "Instagram"
      elsif body.match?(/LinkedIn/i)
        "LinkedIn"
      else
        "General"
      end
    end
  end
end
