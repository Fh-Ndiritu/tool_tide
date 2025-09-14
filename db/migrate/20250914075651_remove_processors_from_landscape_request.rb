class RemoveProcessorsFromLandscapeRequest < ActiveRecord::Migration[8.0]
  def change
    remove_column :landscape_requests, :image_engine
  end
end
