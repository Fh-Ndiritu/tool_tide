class CreateBlogLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_locations do |t|
      t.string :country
      t.string :region_category
      t.string :state
      t.string :city
      t.string :major_counties
      t.text :focus
      t.datetime :last_processed_at

      t.timestamps
    end
  end
end
