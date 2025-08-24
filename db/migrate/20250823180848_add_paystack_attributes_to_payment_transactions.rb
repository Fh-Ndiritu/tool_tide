class AddPaystackAttributesToPaymentTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :payment_transactions, :status, :integer, default: 0, null: false
    add_column :payment_transactions, :paid_at, :datetime
    add_column :payment_transactions, :method, :string
    add_column :payment_transactions, :paystack_customer_id, :string
    add_column :payment_transactions, :currency, :string, default: 'USD'
  end
end
