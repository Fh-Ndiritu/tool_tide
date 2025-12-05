class DropSearchTerms < ActiveRecord::Migration[8.0]
  def change
    drop_table :search_terms, if_exists: true do |t|
      t.string :term
      t.integer :user_id
      t.timestamps
      t.string :ip_address
      t.string :city
      t.string :country
      t.float :latitude
      t.float :longitude
      t.index :user_id
    end
  end
end
