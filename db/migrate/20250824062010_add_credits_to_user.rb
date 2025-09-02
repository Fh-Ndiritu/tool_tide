# frozen_string_literal: true

class AddCreditsToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :pro_engine_credits, :integer, default: 0
    add_column :users, :free_engine_credits, :integer, default: 0
    add_column :users, :received_daily_credits, :boolean, default: false, null: false
  end
end
