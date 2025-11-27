class CreateSearchTerms < ActiveRecord::Migration[8.0]
  def change
    create_table :search_terms do |t|
      t.string :term
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end
  end
end
