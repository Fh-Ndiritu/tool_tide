module Agora
  class FinalPolishJob < ApplicationJob
    queue_as :default

    # Platform-specific aspect ratios (Gemini 3 Pro supported: 1:1, 2:3, 3:2, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9)
    PLATFORM_ASPECT_RATIOS = {
      "tiktok" => { ratio: "9:16", description: "vertical/portrait for full-screen mobile" },
      "instagram" => { ratio: "4:5", description: "portrait for feed" },
      "facebook" => { ratio: "1:1", description: "square for feed" },
      "linkedin" => { ratio: "16:9", description: "landscape for feed" },
      "pinterest" => { ratio: "2:3", description: "vertical/portrait for pins" },
      "twitter" => { ratio: "16:9", description: "landscape for timeline" },
      "youtube" => { ratio: "16:9", description: "landscape for thumbnails" }
    }.freeze

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
        instagram_text: brief["instagram_text"],
        linkedin_text: brief["linkedin_text"],
        pinterest_text: brief["pinterest_text"],
        twitter_text: brief["twitter_text"],
        youtube_description: brief["youtube_description"],
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
        string :facebook_text, description: "Optimized ad copy for Facebook Feed/Reels"
        string :instagram_text, description: "Engaging caption for Instagram Grid/Reels/Stories"
        string :linkedin_text, description: "Professional yet engaging post text for LinkedIn"
        string :pinterest_text, description: "SEO-optimized pin description with keywords for Pinterest"
        string :twitter_text, description: "Concise, punchy text for X/Twitter (max 280 chars)"
        string :youtube_description, description: "Optimized description for YouTube Shorts"
        string :admin_notes, description: "Additional strategic notes for the execution team"
      end
    end

    def generate_brief(post, context)
      # Fetch website link from brand context if available
      website_context = Agora::BrandContext.find_by(key: "website.md")
      website_url = website_context&.metadata&.dig("website_url") || "our website"

      # Get persona and archetype from root post (maintained through revision cycle)
      root = post.root
      persona = root.persona_context&.with_indifferent_access || {}
      archetype_type = root.content_archetype
      archetype = CONTENT_ARCHETYPES.find { |a| a[:type] == archetype_type } || {}

      prompt = <<~PROMPT
        You are the "Execution Lead" for the Agora Forum.

        ═══════════════════════════════════════════════════════════════
        CRITICAL: CONTENT FIDELITY REQUIREMENTS
        ═══════════════════════════════════════════════════════════════

        You MUST base ALL output strictly on the ACCEPTED IDEA below.
        - The post title and body are your PRIMARY source of truth
        - DO NOT invent new concepts, features, or messaging not in the post
        - Extract and amplify the SPECIFIC hooks, angles, and value props from the post
        - Every platform text must be a faithful adaptation of THIS post's message
        - If the post mentions specific features, benefits, or scenarios - USE THEM
        - Rephrase and reword the content for each platform appropriately.

        ═══════════════════════════════════════════════════════════════
        ACCEPTED IDEA (THIS IS YOUR SOURCE MATERIAL)
        ═══════════════════════════════════════════════════════════════

        Title: #{post.title}

        Full Content:
        #{post.body}

        ═══════════════════════════════════════════════════════════════
        CREATIVE CONTEXT (Maintain through execution)
        ═══════════════════════════════════════════════════════════════

        Persona: #{persona[:name] || 'Not specified'}
        - Voice/Style: #{persona[:pitch_style] || 'N/A'}
        - Worldview: #{persona[:worldview] || 'N/A'}

        Content Archetype: #{archetype_type || 'Not specified'}
        - Goal: #{archetype[:goal] || 'N/A'}
        - Success Criteria: #{archetype[:success_criteria] || 'N/A'}

        Website Link: #{website_url}

        ═══════════════════════════════════════════════════════════════
        BRAND CONTEXT (Reference only, do NOT override post content)
        ═══════════════════════════════════════════════════════════════

        #{context}

        ═══════════════════════════════════════════════════════════════
        TASK
        ═══════════════════════════════════════════════════════════════

        Transform the ACCEPTED IDEA above into execution-ready assets:

        1. VIDEO PROMPT: Describe a video that brings THIS post's message to life
           - Avoid excessive text overlays/banners (reduces quality)
           - Focus on visual storytelling of the post's core concept
           - If your prompt will involve showing text in the video more than twice, it will be rejected right away!
           - Our videos are ONLY 5 seconds long.

        2. IMAGE PROMPT: Describe an image that captures THIS post's essence
           - High quality, 4K, professional resolution
           - Visual representation of the post's key message
           - We must achieve the highest possible quality, 4k realistic look.
           - CRITICAL ASPECT RATIO: Generate in #{aspect_ratio_for_platform(post.platform)[:ratio]} format (#{aspect_ratio_for_platform(post.platform)[:description]})

        3. PLATFORM TEXTS: Adapt THIS post for each platform:
           * TikTok: Casual, viral, trend-aware - but about THIS post's topic
           * Facebook: Emotional hook from THIS post's content
           * Instagram: Visual-first caption about THIS post's message
           * LinkedIn: Professional take on THIS post's insights
           * Pinterest: SEO-rich description of THIS post's value
           * Twitter/X: Punchy <280 chars distillation of THIS post
           * YouTube: Description with THIS post's key points

        ═══════════════════════════════════════════════════════════════
        QUALITY CHECKS (Before responding)
        ═══════════════════════════════════════════════════════════════

        ✓ Does every output directly relate to the post's title and body?
        ✓ Am I using specific hooks/angles FROM the post (not inventing new ones)?
        ✓ Would someone reading the post recognize these as adaptations of it?
        ✓ Have I maintained the persona's voice and archetype's goal?

        Output using the provided schema. Use GitHub Flavored Markdown for all texts.
      PROMPT

      # Use RubyLLM for structured output as requested
      response = CustomRubyLLM.context.chat.with_schema(BriefSchema).ask(prompt)
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

    def aspect_ratio_for_platform(platform)
      normalized = platform.to_s.downcase.strip
      PLATFORM_ASPECT_RATIOS[normalized] || { ratio: "1:1", description: "square (universal fallback)" }
    end
  end
end
