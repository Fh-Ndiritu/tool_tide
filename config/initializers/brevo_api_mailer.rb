# frozen_string_literal: true

require "brevo"

class BrevoApiMailer
  def initialize(_settings)
    @api_key = ENV.fetch("BREVO_API_KEY")
  end

  def deliver!(mail)
    Rails.logger.debug "DEBUG: Calling Brevo API to send mail..."
    # The configuration is now local to this method call.
    Brevo.configure do |config|
      config.api_key["api-key"] = @api_key
    end
    api_instance = Brevo::TransactionalEmailsApi.new

    brevo_email = Brevo::SendSmtpEmail.new(
      to: [
        Brevo::SendSmtpEmailTo.new(
          email: mail.to.first,
          name: mail.to.first
        )
      ],
      sender: Brevo::SendSmtpEmailSender.new(
        email: mail.from.first,
        name: mail.from.first
      ),
      reply_to: [
        Brevo::SendSmtpEmailReplyTo.new(
          email: mail.reply_to.first,
          name: mail.reply_to.first
        )
      ],
      subject: mail.subject,
      htmlContent: mail.html_part&.decoded || mail.body.decoded
    )

    api_instance.send_transac_email(brevo_email)
  rescue Brevo::ApiError => e
    Rails.logger.error "Brevo failed to send email: #{e.response_body}"
    raise
  end
end
