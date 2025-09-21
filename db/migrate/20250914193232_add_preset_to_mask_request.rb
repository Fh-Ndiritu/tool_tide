class AddPresetToMaskRequest < ActiveRecord::Migration[8.0]
  def change
    add_column :mask_requests, :preset, :string
  end
end
