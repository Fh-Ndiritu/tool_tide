class CreateSubchapters < ActiveRecord::Migration[8.0]
  def change
    create_table :subchapters do |t|
      t.references :chapter, null: false, foreign_key: true
      t.string :title
      t.text :overview
      t.integer :order

      t.timestamps
    end
  end
end
