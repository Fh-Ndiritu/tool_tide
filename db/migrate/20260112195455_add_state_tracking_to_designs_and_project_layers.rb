class AddStateTrackingToDesignsAndProjectLayers < ActiveRecord::Migration[8.0]
  def change
    add_reference :designs, :current_project_layer, foreign_key: { to_table: :project_layers }
    add_column :project_layers, :viewed_at, :datetime
  end
end
