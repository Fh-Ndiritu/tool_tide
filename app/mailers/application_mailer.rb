# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default(
    from: email_address_with_name("winnie@hadaa.app", "Winnie Astrid"),
    reply_to: "winnie@hadaa.app"
  )

  layout "mailer"
end
