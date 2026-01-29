# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  skip_before_action :authenticate_user!, only: [ :create, :new ]

  def create
    super do |resource|
      cookies.permanent[:last_login_method] = "email"
      resource.last_sign_in_device_type = browser.device.mobile? ? "mobile" : "desktop"
      resource.save
    end
  end
end
