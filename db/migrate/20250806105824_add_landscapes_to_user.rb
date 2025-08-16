class AddLandscapesToUser < ActiveRecord::Migration[8.0]
  # We add admin, ip_address, fields,
  change_table :users, bulk: true do |t|
    t.boolean :admin, default: false
    t.string :ip_address
  end
end
