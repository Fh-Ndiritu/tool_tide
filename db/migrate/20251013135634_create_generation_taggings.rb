class CreateGenerationTaggings < ActiveRecord::Migration[8.0]
   def change
    create_table :generation_taggings do |t|
      t.references :tag, null: false, foreign_key: true

      t.references :generation, polymorphic: true, null: false

      t.timestamps
    end
    add_index :generation_taggings, [ :tag_id, :generation_id, :generation_type ], unique: true
  end
end
