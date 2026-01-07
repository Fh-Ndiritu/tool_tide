class CreateOnboardingResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :onboarding_responses do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :role
      t.integer :intent
      t.integer :pain_point
      t.datetime :completed_at

      t.timestamps
    end
  end
end
