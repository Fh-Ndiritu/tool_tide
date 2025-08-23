class PaymentTransactionsController < ApplicationController
  def index
  end

  def create
    # this will be triggered by a user button
    # we create our record and get a reference id
    # then send that to PayStack to initiate transaction
    transaction = create_transaction

    result = PaystackCheckout.perform(transaction)

    payment_url = result.value_or(transaction)&.authorization_url
    if result.failure? || payment_url.nil?
      flash[:alert] = "An error occured, please try again later"
      redirect_to root_path and return
    end

    redirect_to payment_url, allow_other_host: true
  end

  def callback
    redirect_to root_path, "No reference Id found" unless params[:reference]
    result = VerifyPaystackPayment(params[:reference])

    redirect_to root_path, "Payment Failed, please try again later" unless result.sucess?

    # Handle success and issue credits
  end

  private

  def create_transaction
    PaymentTransaction.create!(
    user: current_user,
    amount: 20.00)
  end
end
