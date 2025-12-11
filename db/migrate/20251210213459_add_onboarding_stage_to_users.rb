class AddOnboardingStageToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :onboarding_stage, :integer, default: 0
  end
end
