class RemoveLegacyCreditColumnsFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :received_daily_credits, :datetime
    remove_column :users, :reverted_to_free_engine, :boolean
    remove_column :users, :notified_about_pro_credits, :boolean
    remove_column :users, :restart_onboarding_status, :integer
  end
end
