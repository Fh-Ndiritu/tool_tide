# frozen_string_literal: true

class PaymentTransactionsController < AppController
  def index; end

  def create
    transaction = PaymentTransaction.new_transaction(current_user)

    result = Stripe::InitializeCheckout.perform(transaction, current_user)

    if result.success?
      redirect_to result.value!, allow_other_host: true
    else
      msg = "Stripe Checkout failed: #{result.failure}"
      Rails.logger.error(msg)
      flash[:alert] = "An error occurred, please try again later"
      redirect_to root_path
    end
  end

  def callback
    if params[:session_id]
      # Stripe: Webhook should have processed this by now, or shortly.
      # We just look up the transaction by session_id.
      transaction = PaymentTransaction.find_by(stripe_session_id: params[:session_id])
    else
      # Paystack: Maintain old behavior or update? Assuming Paystack for now.
      # If Paystack also uses webhooks, we should do the same.
      # For now keeping legacy verify for Paystack if not migrating it yet,
      # BUT VerifyPayment calls verify logic.
      # Let's assume we migrated Stripe only as per request.
      result = Paystack::VerifyPayment.perform(params[:reference])
      if result.success?
        flash[:success] = "Payment successful!"
        transaction = PaymentTransaction.find_by(paystack_reference_id: params[:reference])
        set_conversion_event(transaction) if transaction
      else
         flash[:alert] = "Payment Failed, please try again later"
      end
      redirect_to credits_path and return
    end

    if transaction
      if transaction.invoice_success?
        flash[:success] = "Payment successful!"
        set_conversion_event(transaction)
      else
        # Webhook hasn't arrived yet or failed.
        # Check Stripe Status purely for display/polling?
        # User requested to RELY on webhooks.
        # So we tell them "Processing..."
        flash[:notice] = "Payment is processing. Credits will appear shortly."
      end
    else
      flash[:alert] = "Transaction not found."
    end

    redirect_to credits_path
  end

  private

  def set_conversion_event(transaction)
    credits_issued = transaction.credits_issued? ? 0 : (PRO_CREDITS_PER_USD * transaction.amount).to_i
    flash[:conversion_event] = {
      transaction_id: transaction.paystack_reference_id || transaction.stripe_session_id,
      value: transaction.amount.to_f,
      currency: transaction.currency.upcase,
      credits: credits_issued
    }
  end
end
