class SocialPostGenerationJob < ApplicationJob
  queue_as :default

  def perform
    SocialMedia::ContentGenerator.perform
  end
end
