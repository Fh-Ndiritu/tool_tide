module Agora
  class ExecutionsController < ApplicationController
    def index
      # Day-based pagination: page 0 = today, page 1 = yesterday, etc.
      @day_offset = params[:day].to_i
      @current_date = @day_offset.days.ago.to_date

      # Get executions for the selected day
      day_start = @current_date.beginning_of_day
      day_end = @current_date.end_of_day

      @executions = Agora::Execution.includes(:post)
                                     .where(created_at: day_start..day_end)
                                     .order(created_at: :desc)

      # Check if there are older executions for navigation
      @has_older = Agora::Execution.where("created_at < ?", day_start).exists?
      @has_newer = @day_offset > 0
    end

    def show
      @execution = Agora::Execution.find(params[:id])
    end

    def update
      # Placeholder for metric ingestion
    end

    def generate_image
      execution = Agora::Execution.find(params[:id])

      if execution.present?
        Agora::ExecutionImageGenerationJob.perform_later(execution.id)
        redirect_back(fallback_location: agora_executions_path, notice: "🎨 Image Generation Started for Execution ##{execution.id}")
      else
        redirect_back(fallback_location: agora_dashboard_index_path, alert: "Execution not found.")
      end
    end

    def upload_analytics
      execution = Agora::Execution.find(params[:id])
      if execution.update(analytics_screenshot: params[:analytics_screenshot])
        Agora::AnalyzeExecutionMetricsJob.perform_later(execution.id)
        redirect_back(fallback_location: agora_executions_path, notice: "📊 Analyzing screenshot... Metrics will update shortly!")
      else
        redirect_back(fallback_location: agora_executions_path, alert: "Failed to upload screenshot.")
      end
    end
  end
end
