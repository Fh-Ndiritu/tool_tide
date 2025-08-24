class ApplicationMailer < ActionMailer::Base
  default(
    from: email_address_with_name(Rails.application.credentials.dig(:brevo, :sender_email), Rails.application.credentials.dig(:brevo, :sender_name)),
    reply_to: Rails.application.credentials.dig(:brevo, :reply_to)
  )

  layout "mailer"

  private
end
