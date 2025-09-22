class AddUserPrivacyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :privacy_policy, :boolean, default: false
  end
end
