class BlogPostSchema < RubyLLM::Schema
  object :blog_post do
    object :metadata do
      string :title, description: "The SEO Title of the Blog Post"
      string :description, description: "The Meta Description"
      string :primary_keyword, description: "The Primary Keyword"
      array :lsi_keywords, description: "List of LSI Keywords" do
        string :keyword, description: "The LSI Keyword"
      end
      string :url_slug, description: "The URL Slug (e.g., location-state-guide)"
    end
    string :content, description: "The full markdown content of the blog post"
  end
end

class BlogHTMLSchema < RubyLLM::Schema
  object :blog_post do
    string :html_content, description: "The raw HTML string of the blog post"
  end
end

class BlogGeneratorService
  def initialize(blog_id)
    @blog = Blog.find(blog_id)
  end

  def self.perform(blog_id)
    new(blog_id).generate
  end

  def generate
    generate_deep_dive unless @blog.raw_deep_dive.present?

    generate_blog_content

    generate_blog_html
  end

  private

  def generate_deep_dive
    prompt = PROMPTS["blog"]["deep_dive_questions"].gsub("<<LOCATION>>", @blog.location_name)

    response = RubyLLM.chat(model: "mistral-large-latest", provider: "mistral").ask(prompt)
    @blog.update!(raw_deep_dive: response.content)
  end

  def generate_blog_content
    related_blogs = Blog.where.not(id: @blog.id).sample(4).map do |b|
      "- [#{b.title}](/landscaping-guides/#{b.slug.split('/').last})"
    end.join("\n")

    prompt = PROMPTS["blog"]["questions_to_blog"]
             .gsub("<<deep_dive_answers>>", @blog.raw_deep_dive)
             .gsub("<<related_blogs>>", related_blogs)

    response = RubyLLM.chat.with_schema(BlogPostSchema).ask(prompt)

    data = response.content["blog_post"]
    metadata = data["metadata"]

    raw_slug = metadata["url_slug"].to_s.split("/").last
    final_slug = "landscaping-guides/#{raw_slug}"

    @blog.update!(
      title: metadata["title"],
      content: data["content"],
      metadata: metadata.except("url_slug"),
      slug: final_slug
    )
  end

  def generate_blog_html
    design_guidelines = File.read(Rails.root.join("BLOG_DESIGN_GUIDELINES.md"))
    reference_image = Rails.root.join("app/assets/images/brush_prompt.png")

    prompt = PROMPTS["blog"]["markdown_to_html"]
             .gsub("<<markdown_content>>", @blog.content)
             .gsub("<<design_guidelines>>", design_guidelines)

    response = RubyLLM.chat.ask(prompt, with: reference_image)
    html_content = response.content.gsub("```html", "").gsub("```", "")

    @blog.update!(
      html_content: html_content,
      published: true
    )
  end
end
