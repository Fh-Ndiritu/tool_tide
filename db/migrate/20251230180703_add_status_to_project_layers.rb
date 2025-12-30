class AddStatusToProjectLayers < ActiveRecord::Migration[8.0]
  def change
    add_column :project_layers, :status, :integer
  end
end
