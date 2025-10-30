class AddLikedToFavorites < ActiveRecord::Migration[8.0]
  def change
    add_column :favorites, :liked, :boolean
  end
end
