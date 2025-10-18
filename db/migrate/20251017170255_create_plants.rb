class CreatePlants < ActiveRecord::Migration[8.0]
  def change
    create_table :plants do |t|
      t.string :english_name
      t.string :colors
      t.integer :quantity
      t.string :full_size

      t.timestamps
    end
  end
end
