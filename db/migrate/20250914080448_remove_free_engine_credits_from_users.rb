class RemoveFreeEngineCreditsFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :free_engine_credits
  end
end
