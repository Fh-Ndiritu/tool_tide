class CreateLandscapes < ActiveRecord::Migration[8.0]
  def change
    create_table :landscapes do |t|
      t.text :prompt

      t.timestamps
    end
  end
end
