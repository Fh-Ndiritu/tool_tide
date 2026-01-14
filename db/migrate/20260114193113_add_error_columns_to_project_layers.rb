class AddErrorColumnsToProjectLayers < ActiveRecord::Migration[8.0]
  def change
    add_column :project_layers, :error_msg, :string
    add_column :project_layers, :user_msg, :string
  end
end
