module Agora
  class PostsController < ApplicationController
    def show
      @post = Agora::Post.includes(:comments, :votes).find(params[:id])
    end

    def generate
      Agora::PitchGeneratorJob.perform_later

      respond_to do |format|
        format.turbo_stream {
          flash.now[:notice] = "🚀 Pitch Generator triggered! Watch for new activity."
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flash")
        }
        format.html { redirect_back(fallback_location: agora_dashboard_index_path, notice: "🚀 Pitch Generator triggered!") }
      end
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
