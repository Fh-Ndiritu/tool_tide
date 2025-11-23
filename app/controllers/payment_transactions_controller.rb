# frozen_string_literal: true

class PaymentTransactionsController < ApplicationController
  def index; end

  def create
    transaction = PaymentTransaction.new_transaction(current_user)
    transaction.save!

    result = Paypal::CreateOrder.perform(transaction)

    if result.success?
      order = result.value!
      Rails.logger.info "PayPal Order Created: #{order.inspect}"
      # Ensure we return a hash with the ID, as the SDK object might not serialize correctly
      render json: { id: order.id, status: order.status }
    else
      Rails.logger.error "PayPal Order Creation Failed: #{result.failure}"
      render json: { error: result.failure }, status: :unprocessable_entity
    end
  end

  def capture
    result = Paypal::CaptureOrder.perform(params[:order_id])

    if result.success?
      # Update transaction with PayPal details
      # We need to find the transaction first. For now, let's assume we can find it via some metadata or we just create a record if needed.
      # Actually, the CreateOrder service used the transaction UUID as reference_id.
      # The capture response should contain purchase_units with reference_id.

      capture_data = result.value!
      reference_id = capture_data.purchase_units.first.reference_id
      transaction = PaymentTransaction.find_by(uuid: reference_id)

      if transaction
        transaction.update!(
          paypal_order_id: capture_data.id,
          paypal_payer_id: capture_data.payer.payer_id,
          status: :success,
          paid_at: Time.current,
          method: "paypal",
          validated: true
        )
        transaction.issue_credits

        # Return the full order data for frontend error handling
        render json: capture_data.to_hash
      else
         render json: { error: "Transaction not found" }, status: :not_found
      end
    else
      # Return detailed error information for frontend handling
      error_info = result.failure
      if error_info.is_a?(Hash)
        render json: error_info, status: :unprocessable_entity
      else
        render json: { error: error_info }, status: :unprocessable_entity
      end
    end
  end
end
