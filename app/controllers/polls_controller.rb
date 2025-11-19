class PollsController < ApplicationController
  # Ensure the user is logged in to vote
  before_action :authenticate_user!

  # POST /features/:feature_id/polls
  def create
    # Find the feature being voted on
    feature = Feature.find(params[:feature_id])
    # Expects 1 for "Nice to Have Next" preference
    preference = params[:preference].to_i

    # Find the existing poll by the current user for this feature
    @poll = feature.polls.find_or_initialize_by(user: current_user)

    if @poll.new_record? || @poll.preference != preference
      # If new or changing preference, save the vote
      @poll.preference = preference
      @poll.save!
    else
      # If clicking the same vote again, destroy the poll (unvote)
      @poll.destroy!
    end

    # Respond with a Turbo Stream to update the score display instantly
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          # Target the unique ID defined in _polling_block.html.erb
          "feature_#{feature.id}_polling_block",
          partial: "features/polling_block",
          locals: { feature: feature }
        )
      end
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
    # Handle cases where the feature or poll operation fails
    head :unprocessable_entity
  end
end
