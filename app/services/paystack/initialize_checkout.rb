# frozen_string_literal: true

module Paystack
  class InitializeCheckout
    include Dry::Monads[:result]
    include Moneyable

    def initialize(transaction)
      @transaction = transaction
    end

    def self.perform(*args)
      new(*args).perform
    end

    def perform
      verify_transaction
      .bind { fetch_checkout_code }
      .bind { |checkout_content| validate_data(checkout_content) }
      .bind { |valid_data| update_payment_transaction(valid_data) }
      .bind { Success(@transaction.reload) }
    rescue StandardError => e
      Failure("Paystack Checkout failed: #{e.message}")
    end

    private

    def fetch_checkout_code
      response = client.post("/transaction/initialize") do |req|
        req.body = {
          email: @transaction.email,
          amount: to_subunit(@transaction.amount),
          currency: "USD",
          reference: @transaction.uuid,
          callback_url: ENV.fetch("PAYSTACK_CALLBACK_URL"),
          metadata: {
            'user_id': @transaction.user_id,
            'tx_id': @transaction.id
          }
      }.to_json
      end
      content = JSON.parse(response.body, symbolize_names: true)
      Success(content)
    rescue Faraday::Error => e
      Failure("Faraday failed with: status#{e.response_status}, body: #{e.response_body}")
    rescue StandardError => e
      Failure("fetch_checkout_code failed: #{e.message}")
    end

    # this is valid if user has required fields
    # And if the record has not previous payment details
    def verify_transaction
      # this is already an initialized transaction
      return Failure("Transaction already has an access code") if @transaction.access_code.present?

      return Failure("Amount or reference id is missing") unless @transaction.amount.to_i.positive? && @transaction.uuid.present?

      Success(true)
    end


    def update_payment_transaction(data)
      if @transaction.update(access_code: data[:access_code], authorization_url: data[:authorization_url])
        Success(@transaction)
      else
        Failure(@transaction.errors.full_messages)
      end
    end


    def validate_data(content)
      data = content[:data]
      return Failure("PayStack Status is not true") if content[:status] != true

      return Failure("Paystack access_code or authorization_url is blank") if data[:access_code].blank? || data[:authorization_url].blank?

      return Failure("Paystack reference key has changed") if @transaction.uuid != data[:reference]

      Success(data)
    end

    def client
      @client ||= Faraday.new(
        url: ENV.fetch("PAYSTACK_BASE_URL"),
        headers:  { "Content-Type" => "application/json" }
        ) do |conn|
        conn.request :authorization, "Bearer", ENV.fetch("PAYSTACK_API_KEY")
        conn.response :raise_error
      end
    end
  end
end
