class CreateNarrationScenes < ActiveRecord::Migration[8.0]
  def change
    create_table :narration_scenes do |t|
      t.references :subchapter, null: false, foreign_key: true
      t.integer :order
      t.text :content_overview
      t.text :narration_text
      t.json :dialogue_content
      t.integer :duration

      t.timestamps
    end
  end
end
