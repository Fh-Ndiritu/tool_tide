# frozen_string_literal: true

module Paystack
  class VerifyPayment
    include Dry::Monads[:result]
    include Moneyable

    def initialize(paystack_reference_id)
      @reference = paystack_reference_id
    end

    def self.perform(*args)
      new(*args).perform
    end

    def perform
      return Failure("Reference id is not present") if @reference.empty?

      fetch_transaction
        .bind { |transaction| update_payment_transaction(transaction) }
        .bind { |payment_transaction| Success(payment_transaction) }
    rescue StandardError => e
      Failure("#{self.class} failed with error: #{e.message}")
    end

    private

    def update_payment_transaction(transaction)
      # we find the transaction using the tx_id metadata field
      # if we can't find one we can create using the customer and update
      fetch_customer(transaction).bind do |user|
        tx_id = transaction.dig(:metadata, :tx_id)
        payment_transaction = PaymentTransaction.find_by(id: tx_id) || PaymentTransaction.new_transaction(user)

        save_event_details(payment_transaction, transaction)
          .bind { validate_successful_payment(payment_transaction, transaction) }
      end
    rescue StandardError => e
      Failure("#{__method__} failed: #{e.message}")
    end

    def save_event_details(payment_transaction, transaction)
      if payment_transaction.update!(
        status: transaction[:status],
        paystack_reference_id: transaction[:reference],
        paid_at: transaction[:paid_at],
        method: transaction[:channel],
        paystack_customer_id: transaction.dig(:customer, :customer_code)
      )
        Success(payment_transaction)
      else
        Failure("!! Failed to save payment details: #{payment_transaction.errors.full_messages}")
      end
    rescue StandardError => e
      Failure("#{__method__} failed: #{e.message}")
    end

    def validate_successful_payment(payment_transaction, transaction)
      if transaction[:amount] != to_subunit(payment_transaction.amount)
        Failure("User #{payment_transaction.user.id} paid #{transaction[:currency]} #{from_subunit(transaction[:amount])} instead of #{payment_transaction.amount}")
      elsif transaction[:currency] != payment_transaction.currency
        Failure("#{transaction[:currency]} is not the expected currency of #{payment_transaction.currency}")
      else
        ActiveRecord::Base.transaction do
          payment_transaction.update validated: true
          payment_transaction.issue_credits
          payment_transaction.user.update pro_trial_credits: 0
        end
        Success(payment_transaction)
      end
    rescue StandardError => e
      Failure("#{__method__} failed: #{e.message}")
    end

    def fetch_customer(transaction)
      # we get back two reliable user details we can use
      # We shall default to email which is unique and part of the main response
      email = transaction.dig(:customer, :email)
      user_id = transaction.dig(:metadata, :user_id)

      user = User.find_by(email:) || User.find_by(id: user_id)
      return Failure("User not found with ID or Email") if user.blank?

      Success(user)
    rescue StandardError => e
      Failure("#{__method__} failed: #{e.message}")
    end

    def fetch_transaction
      response = PAYSTACK_CLIENT.get("/transaction/verify/#{@reference}")
      transaction = JSON.parse(response.body, symbolize_names: true)
      Success(transaction[:data])
    rescue Faraday::Error => e
      Failure("Faraday failed with: status#{e.response_status}, body: #{e.response_body}")
    rescue StandardError => e
      Failure("#{__method__} failed: #{e.message}")
    end
  end
end
