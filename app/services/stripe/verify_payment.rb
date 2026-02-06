# frozen_string_literal: true

module Stripe
  class VerifyPayment
    include Dry::Monads[:result]

    def initialize(event)
      @event = event
    end

    def self.perform(event)
      new(event).perform
    end

    def perform
      Success(@event)
        .bind { |event| extract_session(event) }
        .bind { |session| verify_payment_status(session) }
        .bind { |session| find_transaction(session) }
        .bind { |transaction| issue_credits(transaction) }
        .bind { |transaction| Success(transaction) }
    rescue StandardError => e
      Failure("Stripe Webhook Failed: #{e.message}")
    end

    private

    def extract_session(event)
      # Ensure it's the correct event type if needed, or trust the caller subscription
      session = event.data.object
      Success(session)
    end

    def verify_payment_status(session)
      if session.payment_status == "paid"
        Success(session)
      else
        Failure("Payment not paid. Status: #{session.payment_status}")
      end
    end

    def find_transaction(session)
      # client_reference_id should be our payment_transaction.id
      transaction_id = session.client_reference_id
      transaction = PaymentTransaction.find_by(id: transaction_id)

      if transaction
        # Update session ID if missing
        transaction.update(stripe_session_id: session.id) if transaction.stripe_session_id.blank?
        Success(transaction)
      else
        # Fallback: Look up by stripe_session_id
        transaction = PaymentTransaction.find_by(stripe_session_id: session.id)
        return Success(transaction) if transaction

        Failure("PaymentTransaction not found for Session: #{session.id}")
      end
    end

    def issue_credits(transaction)
      # Idempotent: issue_credits in model checks if already issued
      if transaction.update(status: :success, validated: true)
        transaction.issue_credits
        Success(transaction)
      else
        Failure("Failed to update transaction: #{transaction.errors.full_messages}")
      end
    end
  end
end
