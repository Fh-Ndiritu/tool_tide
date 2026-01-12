class CreateProjectLayers < ActiveRecord::Migration[8.0]
  def change
    create_table :project_layers do |t|
      t.references :project, null: false, foreign_key: true
      t.references :design, null: false, foreign_key: true
      t.string :ancestry
      t.integer :layer_type
      t.integer :progress, default: 0
      t.integer :transformation_type
      t.integer :views_count, default: 0
      t.text :prompt
      t.string :preset

      t.timestamps
    end
    add_index :project_layers, :ancestry
  end
end
