class AddCompletedSurveyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :completed_survey, :boolean
  end
end
