class RenameColorsToDescriptionPlants < ActiveRecord::Migration[8.0]
  def change
    rename_column :plants, :colors, :description
    remove_column :plants, :quantity
    add_column :plants, :size, :string
    add_column :mask_request_plants, :quantity, :integer
  end
end
