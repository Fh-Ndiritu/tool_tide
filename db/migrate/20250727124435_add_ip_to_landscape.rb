class AddIpToLandscape < ActiveRecord::Migration[8.0]
  change_table :landscapes, bulk: true do |t|
    t.string :ip_address
  end
end
