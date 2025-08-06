class AddUseLocationToLandscape < ActiveRecord::Migration[8.0]
  def change
    add_column :landscapes, :use_location, :boolean, default: false, null: false
  end
end
