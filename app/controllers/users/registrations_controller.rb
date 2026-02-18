# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |resource|
      cookies.permanent[:last_login_method] = "email"
    end
  end

  protected

  def sign_up_params
    device_type = browser.device.mobile? ? "mobile" : "desktop"
    super.merge(last_sign_in_device_type: device_type)
  end
end
