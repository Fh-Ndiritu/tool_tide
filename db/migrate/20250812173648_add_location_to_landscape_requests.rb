class AddLocationToLandscapeRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :landscape_requests, :use_location, :boolean, default: false, null: false
  end
end
