class CreateCreditVouchers < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_vouchers do |t|
      t.string :token, null: false
      t.references :user, null: false, foreign_key: true
      t.integer :amount, default: 50, null: false
      t.datetime :redeemed_at
      t.timestamps
    end
    add_index :credit_vouchers, :token, unique: true
  end
end
