module SocialMedia
  class ContentGenerationSchema < RubyLLM::Schema
    array :posts do
      object do
        string :content, description: "Engaging Facebook caption with emojis and a hook."
        string :prompt, description: "Detailed image generation prompt for a photorealistic garden/landscape."
        array :tags, description: "List of relevant hashtags." do
          string :tag
        end
      end
    end
  end

  class ContentGenerator
    def self.perform
      new.generate
    end

    def generate
      context = build_context
      ideas = generate_ideas(context)

      ideas.each do |idea|
        create_post(idea)
      end
    end

    private

    def build_context
      last_posts = SocialPost.order(created_at: :desc).limit(5).map do |p|
        "Post: #{p.content} | Score: #{p.performance_score || 'N/A'}"
      end.join("\n")



      features = [
        "AI Brush: Paint materials like gravel or mulch.",
        "Prompt Editor: Change styles instantly (Modern, Cottage, Zen).",
        "Planting Guide: Get a shopping list of plants.",
        "Drone View: See your garden from above.",
        "Auto Fix: Detects issues with your garden and provides solutions you can apply with a single click."
      ].join("\n")

      <<~CONTEXT
        Previous Content Performance:
        #{last_posts}



        Hadaa.Pro Features:
        #{features}
      CONTEXT
    end

    def generate_ideas(context)
      system_prompt = <<~SYSTEM
        You are a Social Media Manager for Hadaa.pro (Garden Design AI) with link (https://hadaa.pro).
        Generate 3 viral Facebook post ideas.
        Use the provided context to align with SEO and features.
        Each post must have a caption, tags, and an image prompt.
        ALWAYS ENSURE PHOTOREALISM IN YOUR IMAGES.
        Each hastag can only have 1 # symbol.
      SYSTEM

      # Using standard RubyLLM with schema
      response = RubyLLM.chat()
                        .with_schema(ContentGenerationSchema)
                        .ask(context + "\n\n" + system_prompt)

      response.content["posts"]
    end

    def create_post(idea)
      post = SocialPost.create!(
        content: idea["content"],
        prompt: idea["prompt"],
        tags: idea["tags"],
        platform: 'facebook',
        status: :generated
      )

      # Generate Image
      retry_count = 0
      begin
        image_blob = ImageGenerator.perform(idea["prompt"])
        if image_blob
          post.image.attach(
            io: image_blob,
            filename: "generated_image_#{post.id}.png",
            content_type: "image/png"
          )
        end
      rescue StandardError => e
        Rails.logger.error("Image Generation Failed for Post #{post.id}: #{e.message}")
        # We allow the post to exist without image for debugging, or we could destroy it.
      end

      post
    end
  end
end
