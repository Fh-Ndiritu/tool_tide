class CreateCreditSpendings < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_spendings do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount
      t.integer :transaction_type
      t.references :trackable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
