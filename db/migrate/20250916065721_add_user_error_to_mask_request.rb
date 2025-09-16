class AddUserErrorToMaskRequest < ActiveRecord::Migration[8.0]
  def change
    add_column :mask_requests, :user_error, :string
  end
end
