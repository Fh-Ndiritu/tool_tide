class ProjectOnboardingsController < AppController
  def update
    Rails.logger.info("ProjectOnboarding#update called with params: #{params.inspect}")

    onboarding = current_user.project_onboarding || current_user.create_project_onboarding
    Rails.logger.info("Onboarding record: #{onboarding.inspect}")

    if onboarding.update(onboarding_params)
      Rails.logger.info("Onboarding updated successfully")
      head :ok
    else
      Rails.logger.error("Onboarding update failed: #{onboarding.errors.full_messages}")
      render json: { errors: onboarding.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def onboarding_params
    params.require(:project_onboarding).permit(:style_presets_status, :smart_fix_status, :auto_fix_status)
  end
end
