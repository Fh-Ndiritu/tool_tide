class SetDefaultSmartFixWarningSeenToProjectOnboardings < ActiveRecord::Migration[8.0]
  def change
    change_column_default :project_onboardings, :smart_fix_warning_seen, from: nil, to: false
    ProjectOnboarding.where(smart_fix_warning_seen: nil).update_all(smart_fix_warning_seen: false)
  end
end
