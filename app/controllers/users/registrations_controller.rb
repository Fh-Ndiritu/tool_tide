# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :check_captcha, only: [:create]

  private

  def check_captcha
    return if verify_recaptcha(action: 'signup', minimum_score: 0.5)

    self.resource = resource_class.new sign_up_params
    resource.validate # Look for any other validation errors besides Recaptcha
    resource.errors.add(:base, "Recaptcha verification failed. Please try again.")
    clean_up_passwords(resource)
    set_minimum_password_length
    render :new
  end
end
