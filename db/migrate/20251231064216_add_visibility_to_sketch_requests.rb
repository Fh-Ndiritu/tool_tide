class AddVisibilityToSketchRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :sketch_requests, :visibility, :integer, default: 0
  end
end
