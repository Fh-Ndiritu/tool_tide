# frozen_string_literal: true

class PaymentTransactionsController < AppController
  def index; end

  def create
    # this will be triggered by a user button
    # we create our record and get a reference id
    # then send that to PayStack to initiate transaction
    transaction = PaymentTransaction.new_transaction(current_user)

    result = Paystack::InitializeCheckout.perform(transaction)

    payment_url = result.value_or(transaction)&.authorization_url
    if result.failure? || payment_url.nil?
      msg = "Checkout failed: #{result}"
      Sentry.capture_message(msg)
      Rails.logger.info msg
      flash[:alert] = "An error occured, please try again later"
      redirect_to root_path and return
    end

    redirect_to payment_url, allow_other_host: true and return
  end

  def callback
    redirect_to root_path, alert: "No reference Id found" and return unless params[:reference]

    result = Paystack::VerifyPayment.perform(params[:reference])
    if result.success?
      flash[:success] = "Payment successful!"

      # Set conversion event for GA purchase tracking
      transaction = PaymentTransaction.find_by(paystack_reference_id: params[:reference])
      if transaction
        credits_issued = transaction.credits_issued? ? 0 : (PRO_CREDITS_PER_USD * transaction.amount).to_i
        flash[:conversion_event] = {
          transaction_id: transaction.paystack_reference_id,
          value: transaction.amount.to_f,
          currency: transaction.currency.upcase,
          credits: credits_issued
        }
      end
    else
      flash[:alert] = "Payment Failed, please try again later"
    end

    redirect_to credits_path
  end
end
