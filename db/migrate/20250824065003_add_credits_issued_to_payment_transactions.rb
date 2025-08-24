class AddCreditsIssuedToPaymentTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :payment_transactions, :credits_issued, :boolean, default: false, null: false
  end
end
