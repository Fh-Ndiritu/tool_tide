class CreatePolls < ActiveRecord::Migration[8.0]
  def change
    create_table :polls do |t|
      t.references :feature, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :preference

      t.timestamps
    end
  end
end
