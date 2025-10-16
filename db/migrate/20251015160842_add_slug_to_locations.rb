class AddSlugToLocations < ActiveRecord::Migration[8.0]
  def change
    add_column :locations, :slug, :string
  end
end
