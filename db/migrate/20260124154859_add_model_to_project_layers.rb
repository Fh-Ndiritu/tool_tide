class AddModelToProjectLayers < ActiveRecord::Migration[8.0]
  def change
    add_column :project_layers, :model, :string, default: "pro_mode"
  end
end
