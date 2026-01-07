class AddCompletedToOnboardingResponses < ActiveRecord::Migration[8.0]
  def change
    add_column :onboarding_responses, :completed, :boolean
  end
end
