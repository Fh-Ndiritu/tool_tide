class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  before_action :set_active_storage_url_options
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, only: [ :robots_block, :render_410 ]

  before_action :block_singapore_users
  before_action :enforce_onboarding_survey
  before_action :redirect_to_canva, if: -> { user_signed_in? && devise_controller? }

  def after_sign_in_path_for(resource)
    if resource.is_a?(User) && resource.admin?
      admin_mask_requests_path
    elsif !resource.can_skip_onboarding_survey?
      onboarding_survey_path
    elsif resource.is_a?(User) && resource.onboarding_stage != "completed"
      new_canva_path
    else
      super
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

  def current_user
    raw_user = super

    return nil unless raw_user

    @_decorated_current_user ||= UserDecorator.new(raw_user)
  end

  helper_method :current_user

  private

  def enforce_onboarding_survey
    return unless user_signed_in?
    return if devise_controller?
    return if controller_name == "onboarding_survey"

    return if current_user.can_skip_onboarding_survey?

    redirect_to onboarding_survey_path
  end

  def redirect_to_canva
    # if the path is sign in and user is signed in, redirect to canva
    if request.path == "/users/sign_in" && user_signed_in?
      if current_user.can_skip_onboarding_survey?
        redirect_to new_canva_path
      else
        redirect_to onboarding_survey_path
      end
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :privacy_policy, :user_name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :user_name ])
  end

  def set_active_storage_url_options
    ActiveStorage::Current.url_options = { host: request.host, protocol: request.protocol.delete_suffix(":"), port: request.port }
  end

  def block_singapore_users
    location = LocationService.lookup(request.remote_ip)
    if location&.country_code == "SG"
      Rails.logger.warn("Blocked user from Singapore. IP: #{request.remote_ip}")
      render plain: "Access Forbidden", status: :forbidden
    end
  end
end
