class CreateUserSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :user_settings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :default_model
      t.integer :default_variations

      t.timestamps
    end
  end
end
