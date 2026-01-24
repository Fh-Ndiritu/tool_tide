module SocialMedia
  class ContentGenerationSchema < RubyLLM::Schema
    array :posts do
      object do
        string :internal_title, description: "Unique ID for the post"
        string :selected_archetype, description: "The chosen archetype from the menu"
        string :category_tag, description: "Marketing, Education, or Viral Aesthetic"
        string :visual_description, description: "Detailed description of the image content"
        string :image_generation_prompt, description: "Detailed prompt for 9:16 vertical image generation"
        string :facebook_caption, description: "Full post text with hook, body, and CTA"
        string :safe_zone_check, description: "Confirmation of text/key elements in safe zone (Yes/No)"
        string :hashtags, description: "Space-separated hashtags string"
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
      last_posts = SocialPost.where.not(performance_score: nil).order(performance_score: :desc).limit(5).map do |p|
        "Post: #{p.content} | Score: #{p.performance_score}"
      end.join("\n")

      <<~CONTEXT
        Previous Content Performance:
        #{last_posts}

        Hadaa.Pro link: https://hadaa.pro
        Any past Post with less than a score of 60 is not desirable, we need to keep trying variations and improving.
      CONTEXT
    end

    def generate_ideas(context)
      guidelines = File.read(Rails.root.join("app/services/social_media/prompts/facebook_guidelines.md"))
      system_prompt = <<~SYSTEM
        #{guidelines}

        TASK:
        Generate 3 viral Facebook post ideas based on the context provided.
        Select different archetypes for variety.
        Ensure strict adherence to the JSON Output Schema.
        Hashtags must be carefully selected to maximize reach and engagement and use only one `#` symbol per tag.
        Do not use placeholder links, use https://hadaa.pro when you need a link.
      SYSTEM


      # Using standard RubyLLM with schema
      response = RubyLLM.chat
                        .with_schema(ContentGenerationSchema)
                        .ask(context + "\n\n" + system_prompt)

      response.content["posts"]
    end

    def create_post(idea)
      # Split hashtags string into an array if needed, or keep as string depending on model
      # Assuming tags is an array, we split the string.
      tags_array = idea["hashtags"].scan(/#\w+/)

      post = SocialPost.create!(
        content: idea["facebook_caption"],
        prompt: idea["image_generation_prompt"],
        tags: tags_array,
        platform: 'facebook',
        status: :generated
      )

      # Generate Image
      retry_count = 0
      begin
        image_blob = ImageGenerator.perform(idea["image_generation_prompt"])
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

      # Broadcast the new post to the admin dashboard
      post.broadcast_prepend_to "social_posts",
          target: "social_posts_grid",
          partial: "admin/social_posts/social_post",
          locals: { post: post }

      post
    end
  end
end
