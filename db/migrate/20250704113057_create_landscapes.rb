# frozen_string_literal: true

class CreateLandscapes < ActiveRecord::Migration[8.0]
  def change
    create_table :landscapes, &:timestamps
  end
end
