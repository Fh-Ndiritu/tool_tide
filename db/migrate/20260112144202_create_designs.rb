class CreateDesigns < ActiveRecord::Migration[8.0]
  def change
    create_table :designs do |t|
      t.string :title
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
