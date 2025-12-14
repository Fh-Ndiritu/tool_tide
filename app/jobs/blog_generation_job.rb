class BlogGenerationJob < ApplicationJob
  queue_as :low_priority

  def perform(blog_id)
    BlogGeneratorService.perform(blog_id)
  end
end
