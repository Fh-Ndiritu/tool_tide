class DropSketchRequests < ActiveRecord::Migration[8.0]
  def change
    drop_table :sketch_requests do |t|
      t.references :canva, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :progress, default: 0
      t.integer :visibility, default: 0
      t.text :analysis
      t.text :error_msg
      t.text :user_error
      t.timestamps
    end
  end
end
