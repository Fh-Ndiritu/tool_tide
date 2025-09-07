# frozen_string_literal: true

class AddLocationToUsers < ActiveRecord::Migration[8.0]
  change_table :users, bulk: true do |t|
    t.decimal :latitude, precision: 10, scale: 7
    t.decimal :longitude, precision: 10, scale: 7
    t.json :address
  end
end
