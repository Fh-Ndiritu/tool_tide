class RemoveProTrialCreditsFromUser < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :pro_trial_credits
  end
end
