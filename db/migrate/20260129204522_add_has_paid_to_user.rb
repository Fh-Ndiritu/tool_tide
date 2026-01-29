class AddHasPaidToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :has_paid, :boolean, default: false
  end
end
