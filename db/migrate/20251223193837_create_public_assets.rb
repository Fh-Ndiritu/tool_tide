class CreatePublicAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :public_assets do |t|
      t.string :uuid
      t.string :name

      t.timestamps
    end
    add_index :public_assets, :uuid
  end
end
