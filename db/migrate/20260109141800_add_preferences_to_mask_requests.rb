class AddPreferencesToMaskRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :mask_requests, :preferences, :json, default: {}
  end
end
