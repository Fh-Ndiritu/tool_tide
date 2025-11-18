
class VotesController < ApplicationController
  def create
    voteable = find_voteable
    value = params[:value].to_i

    @vote = voteable.votes.find_or_initialize_by(user: current_user)

    if @vote.new_record? || @vote.value != value
      @vote.value = value
      @vote.save!
      action_type = :update
    else
      @vote.destroy!
      action_type = :destroy
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "issue_#{voteable.id}_voting_block",
          partial: "issues/voting_block",
          locals: { issue: voteable }
        )
      end
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
    head :unprocessable_entity
  end

  private

  def find_voteable
    Issue.find(params[:issue_id])
  end
end
