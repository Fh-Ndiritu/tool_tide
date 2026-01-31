module Agora
  class PostsController < ApplicationController
    def show
      @post = Agora::Post.includes(:comments, :votes).find(params[:id])
    end

    def generate
      Agora::PitchGeneratorJob.perform_later
      redirect_back(fallback_location: agora_dashboard_index_path, notice: "🚀 Pitch Generator trigged! Watch for new activity.")
    end

    def vote
      # Placeholder for Human voting interaction
      # Would update Agora::Vote and broadcast changes
      head :ok
    end

    def proceed
      # Validate Status = Accepted
      # Trigger FinalPolishJob
      # Redirect to Executions
      head :ok
    end
  end
end
