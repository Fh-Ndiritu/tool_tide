class AddValidatedToPlants < ActiveRecord::Migration[8.0]
  def change
    add_column :plants, :validated, :boolean, default: false
  end
end
