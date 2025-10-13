class CreateTextRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :text_requests do |t|
      t.text :prompt
      t.integer :progress
      t.string :user_error
      t.integer :visibility
      t.boolean :trial_generation
      t.belongs_to :user, null: false, foreign_key: true
      t.string :ancestry

      t.timestamps
    end
    add_index :text_requests, :ancestry
  end
end
