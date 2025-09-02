# frozen_string_literal: true

class CreateLandscapeRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :landscape_requests do |t|
      t.belongs_to :landscape, null: false, foreign_key: true
      t.integer :image_engine, default: 0, null: false

      t.timestamps
    end
  end
end
