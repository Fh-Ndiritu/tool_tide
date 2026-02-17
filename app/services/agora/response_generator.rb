module Agora
  class ResponseGenerator
    class DraftResponsesSchema < RubyLLM::Schema
      array :drafts, description: "List of 3 distinct draft responses" do
        object do
          string :response_type, description: "Type of response (Direct Value, Educational, Conversational)"
          string :content, description: "The response text to post"
          string :rationale, description: "Why this response is effective"
        end
      end
    end

    def self.run(opportunity)
      new(opportunity).run
    end

    def initialize(opportunity)
      @opportunity = opportunity
    end

    def run
      # 1. Assemble Context
      brand_context = Agora::ContextAssemblyService.new.assemble

      # 2. Construct Prompt
      # 2. Construct Prompt
      post_content = @opportunity.content.presence || @opportunity.content_snippet
      platform_guide = platform_guidelines(@opportunity.platform)
      identity = platform_identity(@opportunity.platform)

      prompt = <<~PROMPT
      You are a helpful, expert peer participating in a conversation on #{@opportunity.platform}.

      PRIMARY IDENTITY:
      #{identity}

      TASK:
      Generate 3 distinct draft responses based on the POST CONTEXT and BRAND CONTEXT.

      POST CONTEXT:
      Title: #{@opportunity.title}
      Platform: #{@opportunity.platform}
      Content:
      """
      #{post_content}
      """

      BRAND CONTEXT:
      #{brand_context[0..20_000]}

      PLATFORM NUANCES (#{@opportunity.platform}):
      #{platform_guide}

      RESPONSE REQUIREMENTS:
      Each response must include a Contextual Hook. Reference a specific detail, worry, or goal mentioned in the OP's content (e.g., the specific plant type, the slope of their yard, or their budget concerns) to prove you read it.

      ANGLES FOR THE 3 DRAFTS:
      1. The Direct Solver: Focus on one specific feature from the Brand Context that addresses the OP's main pain point.
      2. The Strategic Alternative: Position Hadaa as a smarter, faster, or more affordable alternative to traditional methods like hiring a pro or using complex software.
      3. The Encouraging Validator: Validate the OP's current idea and suggest Hadaa as a way to visualize the plan before they start digging or buying materials.

      STRICT TONE GUIDELINES:
      - No corporate jargon like revolutionary, cutting-edge, or all-in-one.
      - Use I and me statements. Talk about your personal experience with the tool.
      - Vary your opening sentences. Never start two drafts with the same phrase (e.g., avoid starting every draft with I had this problem).
      - Be empathetic. Acknowledge the specific frustration the OP is feeling.
    PROMPT

      # 3. Generate with LLM
      response = CustomRubyLLM.context.chat.with_schema(DraftResponsesSchema).ask(prompt)
      drafts = response.content["drafts"]

      # 4. Save Drafts
      ActiveRecord::Base.transaction do
        drafts.each do |draft|
          @opportunity.draft_responses.create!(
            response_type: draft["response_type"],
            content: draft["content"],
            rationale: draft["rationale"]
          )
        end
      end

      true
    rescue => e
      Rails.logger.error("Response generation failed for Opp##{@opportunity.id}: #{e.message}")
      false
    end

    private


    def platform_identity(platform)
      case platform.to_s.downcase
      when "reddit", "pinterest"
        <<~IDENTITY
          You are NOT a brand representative. You are a real person who found a solution that actually works. Your goal is to help the original poster (OP), not to sell. You happen to use Hadaa for your own projects.
        IDENTITY
      else # linkedin, facebook, instagram
        <<~IDENTITY
          You ARE the creator/maker of Hadaa. You are looking for people who have the exact problem you solved. Your goal is to be helpful first, but transparently offer your tool as a solution that you built specifically for this.
        IDENTITY
      end
    end

    def platform_guidelines(platform)
      case platform.to_s.downcase
      when "reddit"
        <<~GUIDE
          - Tone: Skeptical, authentic, and no-BS. Speak like a regular user of the subreddit.
          - Diction: Use grounded language like: honestly, in my experience, or for what it is worth.
          - Taboos: DO NOT use hashtags. Avoid marketing adjectives like revolutionary or seamless. If you sound like a brochure, you will be roasted.
          - Style: Anecdote-heavy. Mention a specific lesson learned or a feature quirk to prove you are a real human who actually used the tool.
        GUIDE
      when "linkedin"
        <<~GUIDE
          - Tone: Professional, insight-driven, and "builder" focused.
          - Diction: Use terms like: workflow, problem-solving, and "why we built this".
          - Style: Clear and scannable. Use line breaks. 1 or 2 relevant hashtags are okay.
          - Vibe: I saw this problem so often that I decided to build a solution for it.
        GUIDE
      when "instagram"
        <<~GUIDE
          - Tone: Enthusiastic, visual, and "behind-the-scenes" creator vibe.
          - Diction: High energy. Use words like: designed, created, and "love this aesthetic".
          - Style: Short and punchy. Emojis are mandatory (🌿, ✨, 🏡).
          - Vibe: As the creator of Hadaa, I love seeing projects like this. This is exactly why we built the [Feature Name].
        GUIDE
      when "pinterest"
        <<~GUIDE
          - Tone: Curatorial, DIY, and helpful.
          - Diction: Action words like: plan, try, save, and map out.
          - Style: Extremely concise. Focus on the transformation or the end result.
          - Vibe: This is a solid way to visualize that layout you are pinning.
        GUIDE
      when "facebook"
        <<~GUIDE
          - Tone: Friendly, neighborly, and helpful creator.
          - Diction: Standard conversational English. "We" or "I" (as founder).
          - Style: Helpful advice from the team/creator behind the tool.
          - Vibe: We built Hadaa to help with exactly this kind of yard project.
        GUIDE
      else
        "- Be helpful, authentic, and speak from personal experience."
      end
    end
  end
end
