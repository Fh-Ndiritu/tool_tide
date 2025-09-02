# frozen_string_literal: true

class AddUsersToLandscapes < ActiveRecord::Migration[8.0]
  def change
    add_reference :landscapes, :user, foreign_key: true
  end
end
