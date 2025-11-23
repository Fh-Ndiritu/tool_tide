class AddPaypalAndRemovePaystackFromPaymentTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :payment_transactions, :paypal_order_id, :string
    add_column :payment_transactions, :paypal_payer_id, :string

    remove_column :payment_transactions, :paystack_reference_id, :string
    remove_column :payment_transactions, :paystack_customer_id, :string
    remove_column :payment_transactions, :access_code, :string
    remove_column :payment_transactions, :authorization_url, :string
  end
end
