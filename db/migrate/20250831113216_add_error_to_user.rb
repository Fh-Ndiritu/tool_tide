class AddErrorToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :error, :text
  end
end
