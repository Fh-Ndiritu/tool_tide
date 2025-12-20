# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  before_action :check_captcha, only: [:create]

  private

  def check_captcha
    return if verify_recaptcha(action: 'login', minimum_score: 0.5)

    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    flash.now[:alert] = "Recaptcha verification failed. Please try again."
    render :new
  end
end
