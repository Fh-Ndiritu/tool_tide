class AddLayerNumberToProjectLayersAndCounterToDesigns < ActiveRecord::Migration[8.0]
  def up
    add_column :designs, :project_layers_count, :integer, default: 0
    add_column :project_layers, :layer_number, :integer

    # Reset column info to ensure models see new columns
    Design.reset_column_information
    ProjectLayer.reset_column_information

    # Backfill
    Design.find_each do |design|
      Design.reset_counters(design.id, :project_layers)
      design.project_layers.order(:created_at, :id).each_with_index do |layer, index|
        layer.update_columns(layer_number: index + 1)
      end
    end
  end

  def down
    remove_column :designs, :project_layers_count
    remove_column :project_layers, :layer_number
  end
end
