class AddRevertedToFreeEngineToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :reverted_to_free_engine, :boolean, default: false
    add_column :users, :notified_about_pro_credits, :boolean, default: false
  end
end
