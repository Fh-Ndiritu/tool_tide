class CreateCredits < ActiveRecord::Migration[8.0]
  def change
    create_table :credits do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.integer :source, default: 0, null: false
      t.integer :amount, default: 0, null: false
      t.integer :credit_type, default: 0, null: false

      t.timestamps
    end
  end
end
