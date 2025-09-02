# frozen_string_literal: true

class AddProgressToLandscapeRequest < ActiveRecord::Migration[8.0]
  def change
    add_column :landscape_requests, :progress, :integer
  end
end
