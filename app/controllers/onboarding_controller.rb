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
end
