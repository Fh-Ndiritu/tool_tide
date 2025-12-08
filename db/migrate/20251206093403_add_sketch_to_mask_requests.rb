class AddSketchToMaskRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :mask_requests, :sketch, :boolean, default: false
  end
end
