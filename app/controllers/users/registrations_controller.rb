# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :check_captcha, only: [ :create ]
  before_action :configure_sign_up_params, only: [:create]

  def create
    super do |resource|
      cookies.permanent[:last_login_method] = "email"
    end
  end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:last_sign_in_device_type])
  end

  private

  def check_captcha
    return if verify_recaptcha || !Rails.env.production?

    Rails.logger.warn("Recaptcha verification failed. Remote IP: #{request.remote_ip}. Flash Header Error: #{flash[:recaptcha_error]}")

    self.resource = resource_class.new sign_up_params
    resource.validate # Look for any other validation errors besides Recaptcha
    resource.errors.add(:base, "Recaptcha verification failed. Please try again.")
    flash.delete(:recaptcha_error) # Prevent double flash messages
    clean_up_passwords(resource)
    set_minimum_password_length
    render :new, status: :unprocessable_entity
  end
end
