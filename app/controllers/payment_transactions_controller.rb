class PaymentTransactionsController < ApplicationController
  def index
  end

  def create
    # this will be triggered by a user button
    # we create our record and get a reference id
    # then send that to PayStack to initiate transaction
    transaction = create_transaction

    result = Paystack.initializeCheckout.perform(transaction)

    payment_url = result.value_or(transaction)&.authorization_url
    if result.failure? || payment_url.nil?
      flash[:alert] = "An error occured, please try again later"
      redirect_to root_path and return
    end

    redirect_to payment_url, allow_other_host: true
  end

  def callback
    redirect_to root_path, alert: "No reference Id found" unless params[:reference]
    result = Paystack::VerifyPayment.perform(params[:reference])

    if result.failure?
      redirect_to root_path, alert: "Payment Failed, please try again later" and return
    end

    flash[:success] =  "Payment successful!"
    redirect_to root_path
  end
  private

  def create_transaction
    PaymentTransaction.create!(
 er: current_user,
    amount: 20.00)
  end
end
