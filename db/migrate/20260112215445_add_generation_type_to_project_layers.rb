class AddGenerationTypeToProjectLayers < ActiveRecord::Migration[8.0]
  def change
    add_column :project_layers, :generation_type, :integer, default: 0
    add_reference :project_layers, :auto_fix, null: true, foreign_key: true
  end
end
