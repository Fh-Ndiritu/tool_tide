# frozen_string_literal: true

class AddPresetToLandscapeRequest < ActiveRecord::Migration[8.0]
  def change
    add_column :landscape_requests, :preset, :string
  end
end
