class AddSlugToTags < ActiveRecord::Migration[8.0]
  def change
    add_column :tags, :slug, :string
  end
end
