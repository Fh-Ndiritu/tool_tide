class CreateImagePrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :image_prompts do |t|
      t.references :narration_scene, null: false, foreign_key: true
      t.text :prompt
      t.integer :timestamp

      t.timestamps
    end
  end
end
