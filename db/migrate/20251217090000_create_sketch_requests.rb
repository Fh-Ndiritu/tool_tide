class CreateSketchRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :sketch_requests do |t|
      t.references :canva, null: false, foreign_key: true
      t.integer :progress, default: 0
      t.string :error_msg
      t.string :user_error

      t.timestamps
    end
  end
end
