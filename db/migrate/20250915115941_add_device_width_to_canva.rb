class AddDeviceWidthToCanva < ActiveRecord::Migration[8.0]
  def change
    add_column :canvas, :device_width, :integer, default: 400
  end
end
