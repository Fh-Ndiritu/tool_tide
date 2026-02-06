# frozen_string_literal: true

module Stripe
  class InitializeCheckout
    include Dry::Monads[:result]

    def initialize(transaction, user)
      @transaction = transaction
      @user = user
    end

    def self.perform(transaction, user)
      new(transaction, user).perform
    end

    def perform
      find_or_create_customer
        .bind { |customer_id| create_checkout_session(customer_id) }
        .bind { |session| update_transaction(session) }
    rescue StandardError => e
      Failure("Stripe Checkout failed: #{e.message}")
    end

    private

    def find_or_create_customer
      return Success(@user.stripe_customer_id) if @user.stripe_customer_id.present?

      # Search by email first to avoid duplicates if ID missing but user exists in Stripe
      existing_customers = Stripe::Customer.search(query: "email:'#{@user.email}'")
      if existing_customers.data.any?
        customer_id = existing_customers.data.first.id
        @user.update_column(:stripe_customer_id, customer_id)
        return Success(customer_id)
      end

      # Create new customer
      customer = Stripe::Customer.create(
        email: @user.email,
        metadata: {
          user_id: @user.id
        },
        name: @user.name # assuming user has a name field, or fallback to something else
      )

      @user.update_column(:stripe_customer_id, customer.id)
      Success(customer.id)
    rescue Stripe::StripeError => e
      Failure("Stripe Customer Creation failed: #{e.message}")
    end

    def create_checkout_session(customer_id)
      session = Stripe::Checkout::Session.create(
        customer: customer_id,
        line_items: [
          {
            price: ENV.fetch("STRIPE_PRICE_ID"),
            quantity: 1
          }
        ],
        mode: "payment",
        # Redirect to our callback with the session_id
        # Stripe replaces {CHECKOUT_SESSION_ID} with the actual ID after payment
        success_url: Rails.application.routes.url_helpers.stripe_callback_url(session_id: "{CHECKOUT_SESSION_ID}", host: ENV.fetch("APP_HOST", "localhost:3000")),
        cancel_url: Rails.application.routes.url_helpers.credits_url(canceled: true, host: ENV.fetch("APP_HOST", "localhost:3000")),
        client_reference_id: @transaction.id,
        metadata: {
          transaction_id: @transaction.id,
          user_id: @user.id
        }
      )
      Success(session)
    rescue Stripe::StripeError => e
      Failure("Stripe Session Creation failed: #{e.message}")
    end

    def update_transaction(session)
      if @transaction.update(stripe_session_id: session.id, status: :pending)
        Success(session.url)
      else
        Failure(@transaction.errors.full_messages)
      end
    end
  end
end
