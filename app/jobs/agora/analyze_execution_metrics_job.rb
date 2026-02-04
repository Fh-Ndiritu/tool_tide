module Agora
  class AnalyzeExecutionMetricsJob < ApplicationJob
    queue_as :default

    def perform(execution_id)
      execution = Agora::Execution.find(execution_id)
      return unless execution.analytics_screenshot.attached?

      result = Agora::AnalyticsExtractor.perform(execution)

      # Always broadcast to clear the "Analyzing..." state in UI
      # Reload to ensure we broadcast the latest DB state
      execution.reload
      broadcast_update(execution, success: !!result)

      # Trigger Post-Mortem Analysis if analytics were successfully extracted
      Agora::PostMortemJob.perform_later(execution.id) if result
    end

    private

    def broadcast_update(execution, success: true)
      Turbo::StreamsChannel.broadcast_replace_to(
        "agora_stream",
        target: execution, # dom_id is inferred
        partial: "agora/executions/card",
        locals: { execution: execution }
      )

      message = success ? "📊 Analytics Extracted for Execution ##{execution.id}" : "⚠️ Analytics Extraction Failed for Execution ##{execution.id}"
      color = success ? "text-green-400" : "text-red-400"

      Turbo::StreamsChannel.broadcast_append_to(
        "agora_system_status",
        target: "system_status_logs",
        partial: "agora/dashboard/log_entry",
        locals: { message: message, color: color }
      )
    end
  end
end
