class AddErrorToLandscapeRequest < ActiveRecord::Migration[8.0]
  def change
    add_column :landscape_requests, :error, :text
  end
end
