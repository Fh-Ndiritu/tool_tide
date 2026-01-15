class AddMaskRequestIdToProjects < ActiveRecord::Migration[8.0]
  def change
    add_reference :projects, :mask_request, null: true, foreign_key: true
  end
end
