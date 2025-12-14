class BlogGenerationJob < ApplicationJob
  queue_as :default

  def perform(blog_id)
    BlogGeneratorService.perform(blog_id)
  end
end
