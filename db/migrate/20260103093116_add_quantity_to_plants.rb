class AddQuantityToPlants < ActiveRecord::Migration[8.0]
  def change
    add_column :plants, :quantity, :integer
  end
end
