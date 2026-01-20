class AddToolStatusesToProjectOnboardings < ActiveRecord::Migration[8.0]
  def change
    create_table :project_onboardings do |t|
      t.references :user, null: false, foreign_key: true

      t.integer :style_presets_status, default: 0, null: false
      t.integer :smart_fix_status, default: 0, null: false
      t.integer :auto_fix_status, default: 0, null: false

      t.timestamps
    end
  end
end
