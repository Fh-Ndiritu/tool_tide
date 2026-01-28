class UserSettingsController < ApplicationController
  before_action :authenticate_user!

  def update
    @user_setting = current_user.user_setting_with_fallback

    if @user_setting.update(user_setting_params)
      redirect_back fallback_location: projects_path, notice: "Settings updated.", status: :see_other
    else
      redirect_back fallback_location: projects_path, alert: "Could not update settings.", status: :unprocessable_entity
    end
  end

  private

  def user_setting_params
    params.require(:user_setting).permit(:default_model, :default_variations)
  end
end
