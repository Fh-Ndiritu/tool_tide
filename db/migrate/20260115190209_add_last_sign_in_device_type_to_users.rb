class AddLastSignInDeviceTypeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_sign_in_device_type, :string
  end
end
