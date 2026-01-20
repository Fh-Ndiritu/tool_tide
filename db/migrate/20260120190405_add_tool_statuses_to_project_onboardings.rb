class AddToolStatusesToProjectOnboardings < ActiveRecord::Migration[8.0]
  def change
    add_column :project_onboardings, :style_presets_status, :integer
    add_column :project_onboardings, :smart_fix_status, :integer
    add_column :project_onboardings, :auto_fix_status, :integer
  end
end
