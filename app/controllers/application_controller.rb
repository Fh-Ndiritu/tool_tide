# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  before_action :set_active_storage_url_options
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!

  before_action :enforce_onboarding_flow, unless: :devise_controller?
  before_action :block_singapore_users


  def after_sign_in_path_for(resource)
    if resource.is_a?(User) && resource.admin?
      admin_mask_requests_path
    elsif resource.is_a?(User) && resource.onboarding_stage != "completed"
      new_canva_path
    else
      super
    end
  end

  private

  def enforce_onboarding_flow
    return unless user_signed_in?
    return if current_user.onboarding_stage == "completed"

    if current_user.text_requests.complete.exists? && current_user.text_requests.count > 1
      current_user.update(onboarding_stage: "completed")
      return
    end

    return unless [ "canvas", "mask_requests" ].include?(controller_name)

    target_path = case current_user.onboarding_stage
    when "fresh", "welcome_seen"
                    new_canva_path
    when "image_uploaded"
                    latest_canva = current_user.canvas.last
                    latest_canva ? new_canva_mask_request_path(latest_canva) : new_canva_path
    when "mask_drawn"
                    latest_mr = current_user.mask_requests.last
                    latest_mr ? edit_mask_request_path(latest_mr) : new_canva_path
    when "style_selected"
                    latest_mr = current_user.mask_requests.last
                    latest_mr ? plants_mask_request_path(latest_mr) : new_canva_path
    when "plants_viewed", "first_result_viewed"
                    latest_mr = current_user.mask_requests.last
                    latest_mr ? mask_request_path(latest_mr) : new_canva_path
    when "text_editor_opened", "refinement_generated"
                    text_requests_path
    else
                    nil
    end

    if target_path && request.get? && request.path != target_path
      redirect_to target_path
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
      Sentry.capture_message("
        Blocked user from Singapore
      ", level: :warning, extra: { ip: request.remote_ip, country: "SG" })
      render plain: "Access Forbidden", status: :forbidden
    end
  end
end
