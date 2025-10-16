class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.string :name
      t.string :location_type
      t.integer :lat
      t.integer :lng
      t.string :country_code
      t.string :iso3
      t.string :admin_name
      t.string :capital
      t.integer :population
      t.string :external_id

      t.timestamps
    end
    add_index :locations, :location_type
    add_index :locations, :country_code
  end
end
