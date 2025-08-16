class CreateSuggestedPlants < ActiveRecord::Migration[8.0]
  def change
    create_table :suggested_plants do |t|
      t.string :name
      t.text :description
      t.belongs_to :landscape_request, null: false, foreign_key: true

      t.timestamps
    end
  end
end
