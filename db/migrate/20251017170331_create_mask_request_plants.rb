class CreateMaskRequestPlants < ActiveRecord::Migration[8.0]
  def change
    create_table :mask_request_plants do |t|
      t.belongs_to :mask_request, null: false, foreign_key: true
      t.belongs_to :plant, null: false, foreign_key: true

      t.timestamps
    end
  end
end
