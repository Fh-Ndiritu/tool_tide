# frozen_string_literal: true

# app/mailers/user_mailer.rb

class UserMailer < ApplicationMailer
  # The `with` method makes params[:user] available
  def welcome_email
    @user = params[:user]

    mail(
      to: @user.email,
      subject: "Welcome to our Awesome App!"
    )
  end
  def feature_announcement_email
    @user = params[:user]
    @voucher = params[:voucher]

    mail(
      to: @user.email,
      subject: "Question about your garden design"
    )
  end
end
