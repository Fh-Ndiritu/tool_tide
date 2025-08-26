class CreateLandscapes < ActiveRecord::Migration[8.0]
  def change
    create_table :landscapes do |t|

      t.timestamps
    end
  end
end
