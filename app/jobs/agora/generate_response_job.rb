module Agora
  class GenerateResponseJob < ApplicationJob
    queue_as :default

    def perform(opportunity)
      Agora::ResponseGenerator.run(opportunity)
    end
  end
end
