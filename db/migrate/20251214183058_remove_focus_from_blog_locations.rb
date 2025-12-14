class RemoveFocusFromBlogLocations < ActiveRecord::Migration[8.0]
  def change
    remove_column :blog_locations, :focus, :text
  end
end
