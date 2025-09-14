class CreateMaskRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :mask_requests do |t|
      t.integer :device_width
      t.string :error_msg
      t.integer :progress

      t.timestamps
    end
  end
end
