# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  def create
    super do |resource|
      cookies.permanent[:last_login_method] = "email"
    end
  end
end
