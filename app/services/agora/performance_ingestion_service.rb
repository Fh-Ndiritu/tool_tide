module Agora
  class PerformanceIngestionService
    def initialize(post_id, metrics_hash)
      @post = Agora::Post.find(post_id)
      @metrics = metrics_hash
    end

    def process
      # 1. Update or Create Execution Record
      execution = @post.execution || Agora::Execution.new(post: @post)

      execution.metrics = execution.metrics.merge(@metrics)
      execution.executed_at ||= Time.current
      execution.save!

      # 2. Trigger Post-Mortem (RLHF)
      Agora::PostMortemJob.perform_later(execution.id)

      execution
    end
  end
end
