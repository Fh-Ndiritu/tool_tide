# frozen_string_literal: true

module Paypal
  class CaptureOrder
    include Dry::Monads[:result]

    def initialize(order_id)
      @order_id = order_id
    end

    def self.perform(order_id)
      new(order_id).perform
    end

    def perform
      response = PaypalClient.orders.capture_order(
        "id" => @order_id,
        "prefer" => "return=representation"
      )

      if response.data.status == "COMPLETED"
        Success(response.data)
      else
        Failure("Failed to capture PayPal order: #{response.data.status}")
      end
    rescue PaypalServerSdk::ErrorException => e
      # Return detailed error information for frontend handling
      error_details = {
        debug_id: e.debug_id,
        details: e.details,
        message: e.message
      }
      Failure(error_details)
    rescue StandardError => e
      Failure({ message: "PayPal CaptureOrder failed: #{e.message}" })
    end
  end
end
