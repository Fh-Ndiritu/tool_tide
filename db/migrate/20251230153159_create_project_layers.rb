class CreateProjectLayers < ActiveRecord::Migration[8.0]
  def change
    create_table :project_layers do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :layer_type
      t.text :prompt
      t.string :preset
      t.references :parent_layer, null: true, foreign_key: { to_table: :project_layers }

      t.timestamps
    end
  end
end
