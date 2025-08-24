class CreatePaymentTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_transactions do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.string :reference_id
      t.decimal :amount, precision: 10, scale: 2

      t.timestamps
    end
  end
end
