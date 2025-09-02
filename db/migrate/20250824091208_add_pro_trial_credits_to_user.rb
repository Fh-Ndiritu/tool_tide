# frozen_string_literal: true

class AddProTrialCreditsToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :pro_trial_credits, :integer, default: 0
  end
end
