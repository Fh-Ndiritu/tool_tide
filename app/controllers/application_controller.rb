class ApplicationController < ActionController::Base
  include Pagy::Method
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  before_action :configure_permitted_parameters, if: :devise_controller?

  before_action :authenticate_user!
  skip_before_action :authenticate_user!, only: [ :robots, :sitemap, :render_410 ]

  before_action :validate_payment_status, if: :user_signed_in?
  before_action :update_last_sign_in_device_type, if: :user_signed_in?

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

  def robots
    render plain: <<~ROBOTS
      User-agent: *
      Allow: /

      Sitemap: https://hadaa.app/sitemap.xml.gz
    ROBOTS
  end

  def sitemap
    # Serve the sitemap file from the public/sitemaps/app directory
    path = Rails.public_path.join("sitemaps", "app", "sitemap.xml.gz")
    if File.exist?(path)
      send_file path, type: "application/xml", disposition: "inline"
    else
      head :not_found
    end
  end

  def user
    return nil unless current_user

    @_user ||= UserDecorator.new(current_user)
  end

  helper_method :user

  private

  def validate_payment_status
    return if devise_controller?
    return if controller_name == "onboarding_survey"
    return if controller_name == "welcome"
    return if controller_name == "payment_transactions"

    # Priority 1: Onboarding survey must be completed first
    unless current_user.can_skip_onboarding_survey?
      redirect_to onboarding_survey_path and return
    end

    # Priority 2: User must have paid
    unless current_user.has_paid?
      redirect_to welcome_path and return
    end
  end

  def update_last_sign_in_device_type
    device_type = browser.device.mobile? ? "mobile" : "desktop"
    if current_user.last_sign_in_device_type != device_type
      current_user.update(last_sign_in_device_type: device_type)
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :privacy_policy, :user_name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :user_name ])
  end
end
