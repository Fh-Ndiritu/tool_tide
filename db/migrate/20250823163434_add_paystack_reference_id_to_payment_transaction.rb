class AddPaystackReferenceIdToPaymentTransaction < ActiveRecord::Migration[8.0]
  def change
    add_column :payment_transactions, :paystack_reference_id, :string
    rename_column :payment_transactions, :reference_id, :uuid
    add_column :payment_transactions, :validated, :boolean, default: false, null: false
  end
end
