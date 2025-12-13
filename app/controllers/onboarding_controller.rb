class OnboardingController < ApplicationController
  def update
    if current_user.update(onboarding_stage: params[:stage])
      respond_to do |format|
        format.turbo_stream
      end
    else
      head :unprocessable_entity
    end
  end

  def reset
    return unless current_user.admin? || QA_USERS.include?(current_user.id)
    return unless current_user.initial?

    current_user.transaction do
      current_user.restarted!
      current_user.update!(pro_engine_credits: current_user.pro_engine_credits + 60)
    end
    redirect_to root_path, notice: "Onboarding reset successfully."
  end
end
