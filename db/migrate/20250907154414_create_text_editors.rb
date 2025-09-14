class CreateTextEditors < ActiveRecord::Migration[8.0]
  def change
    create_table :text_editors do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.text :prompt

      t.timestamps
    end
  end
end
