class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  before_action :configure_permitted_parameters, if: :devise_controller?

  before_action :authenticate_user!
  skip_before_action :authenticate_user!, only: [ :robots_block, :render_410 ]

  before_action :validate_payment_status, if: :user_signed_in?

  def after_sign_in_path_for(resource)
    if resource.is_a?(User) && resource.admin?
      admin_social_posts_path
    else
      projects_path
    end
  end

  def render_410
    respond_to do |format|
      format.html { render file: "#{Rails.root}/public/410.html", layout: false, status: :gone }
      format.all  { head :gone }
    end
  end

  def robots_block
    render plain: <<~ROBOTS
      User-agent: *
      Disallow: /
    ROBOTS
  end

  def user
    return nil unless current_user

    @_user ||= UserDecorator.new(current_user)
  end

  helper_method :user

  private

  def validate_payment_status
    return if devise_controller?
    # if the user has not paid and is not on welcome page or payments page redirect to welcome page
    if !current_user.has_paid? && controller_name != "welcome" && controller_name != "payment_transactions"
      redirect_to welcome_path and return
    end

    # if the user has paid and not completed onboarding survey redirect to onboarding survey page
    if current_user.has_paid? && controller_name != "onboarding_survey" && !current_user.can_skip_onboarding_survey?
      redirect_to onboarding_survey_path and return
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :privacy_policy, :user_name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :user_name ])
  end
end
