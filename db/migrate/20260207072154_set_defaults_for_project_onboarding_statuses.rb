class SetDefaultsForProjectOnboardingStatuses < ActiveRecord::Migration[8.0]
  def change
    change_column_default :project_onboardings, :style_presets_status, from: nil, to: 0
    change_column_default :project_onboardings, :smart_fix_status, from: nil, to: 0
    change_column_default :project_onboardings, :auto_fix_status, from: nil, to: 0

    ProjectOnboarding.where(style_presets_status: nil).update_all(style_presets_status: 0)
    ProjectOnboarding.where(smart_fix_status: nil).update_all(smart_fix_status: 0)
    ProjectOnboarding.where(auto_fix_status: nil).update_all(auto_fix_status: 0)
  end
end
