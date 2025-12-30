class AddViewsCountToProjectLayers < ActiveRecord::Migration[8.0]
  def change
    add_column :project_layers, :views_count, :integer, default: 0, null: false
  end
end
