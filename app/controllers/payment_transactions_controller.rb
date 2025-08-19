class PaymentTransactionsController < ApplicationController

  def index

  end

  def create
    # this will be triggered by a user button
    # we create our record and get a reference id
    # then send that to PayStack to initiate transaction
    transaction = PaymentTransaction.create(
      user: current_user,
      amount: 20_00
    )

    initialize_checkout(transaction)

    # redirect_to whatever path if failed

    redirect_to transaction.authorization_url
  end

  private

  def initialize_checkout(transaction)
    ## call the service
   return unless result.success?

   data = result.data
   if  transaction.reference_id == data['reference']
     raise "Invalid reference for #{transaction.id}"
   end

    transaction.update!(data.transform_keys(&:to_sym))
  end

end
