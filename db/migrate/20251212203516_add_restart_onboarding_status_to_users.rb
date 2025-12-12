class AddRestartOnboardingStatusToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :restart_onboarding_status, :integer, default: 0
  end
end
