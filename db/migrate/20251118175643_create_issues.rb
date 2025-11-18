class CreateIssues < ActiveRecord::Migration[8.0]
  def change
    create_table :issues do |t|
      t.string :title
      t.text :body
      t.belongs_to :user, null: false, foreign_key: true
      t.integer :category, default: 0
      t.integer :progress, default: 0
      t.date :delivery_date

      t.timestamps
    end
  end
end
