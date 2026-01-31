module Agora
  class ExecutionsController < ApplicationController
    def index
      @executions = Agora::Execution.includes(:post).order(created_at: :desc).limit(50)
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
