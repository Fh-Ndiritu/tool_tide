class AddStripeColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :stripe_customer_id, :string
    add_index :users, :stripe_customer_id
    add_column :payment_transactions, :stripe_session_id, :string
    add_index :payment_transactions, :stripe_session_id
  end
end
