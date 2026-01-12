class CreateAutoFixes < ActiveRecord::Migration[8.0]
  def change
    create_table :auto_fixes do |t|
      t.references :project_layer, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.integer :status

      t.timestamps
    end
  end
end
