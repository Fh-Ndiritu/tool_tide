# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  before_action :check_captcha, only: [ :create ]

  private

  def check_captcha
    return if verify_recaptcha

    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    flash.delete(:recaptcha_error) # Prevent double flash messages if the gem sets one
    flash.now[:alert] = "Recaptcha verification failed. Please try again."
    render :new, status: :unprocessable_entity
  end
end
