class AddVisibilityToMaskRequest < ActiveRecord::Migration[8.0]
  def change
    add_column :mask_requests, :visibility, :integer, default: 0
  end
end
