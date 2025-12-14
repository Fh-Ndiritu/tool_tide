class CreateBlogs < ActiveRecord::Migration[8.0]
  def change
    create_table :blogs do |t|
      t.string :location_name
      t.string :slug
      t.string :title
      t.text :raw_deep_dive
      t.text :content
      t.json :metadata
      t.boolean :published

      t.timestamps
    end
    add_index :blogs, :slug
  end
end
