class AddSmartFixWarningSeenToProjectOnboardings < ActiveRecord::Migration[8.0]
  def change
    add_column :project_onboardings, :smart_fix_warning_seen, :boolean
  end
end
