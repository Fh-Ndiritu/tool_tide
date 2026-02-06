# frozen_string_literal: true

Stripe.api_key = ENV["STRIPE_SECRET_KEY"]

StripeEvent.signing_secret = ENV["STRIPE_WEBHOOK_SECRET"]


StripeEvent.configure do |events|
  events.subscribe "checkout.session.completed" do |event|
    result = Stripe::VerifyPayment.perform(event)

    if result.failure?
      Rails.logger.error("Stripe Webhook Error: #{result.failure}")
    else
      Rails.logger.info("Stripe Webhook Success: Credits Issued for Transaction #{result.value!.id}")
    end
  end
end
