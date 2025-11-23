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

  def credits_purchased_email
    @user = params[:user]
    @transaction = PaymentTransaction.find(params[:transaction_id])
    @credits_issued = params[:credits_issued]

    mail(
      to: @user.email,
      subject: "Your Credits Purchase is Complete! 🎉"
    )
  end
end
