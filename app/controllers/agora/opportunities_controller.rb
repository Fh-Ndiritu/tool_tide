module Agora
  class OpportunitiesController < ApplicationController
    before_action :authenticate_user!

    def index
      @opportunities = Agora::Opportunity.pending
                                         .includes(:draft_responses)
                                         .recent

      if params[:platform].present?
        @opportunities = @opportunities.where(platform: params[:platform])
      end

      if defined?(Pagy)
        @pagy, @opportunities = pagy(@opportunities)
      end
    end

    def update
      @opportunity = Agora::Opportunity.find(params[:id])

      if params[:status] == "posted"
        @opportunity.posted!
        flash[:notice] = "Opportunity marked as posted!"
      elsif params[:status] == "dismissed"
        @opportunity.dismissed!
        flash[:notice] = "Opportunity dismissed."
      end

      redirect_back(fallback_location: agora_opportunities_path)
    end
  end
end
