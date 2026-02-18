module Agora
  class DailyOppScoutJob < ApplicationJob
    queue_as :default

    def perform
      # 1. Scout for new opportunities
      Rails.logger.info("[Agora::DailyOppScoutJob] Starting scout...")
      Agora::OpportunityScout.run

      # 2. Generate responses for pending opportunities
      # Find pending opportunities that don't have draft responses yet
      opportunities = Agora::Opportunity.pending.left_joins(:draft_responses).where(agora_draft_responses: { id: nil })

      jobs = opportunities.map do |opportunity|
        Agora::GenerateResponseJob.new(opportunity)
      end
      ActiveJob.perform_all_later(jobs)

      Rails.logger.info("[Agora::DailyOppScoutJob] Done.")
    end
  end
end
