class AddCurrentDesignToProjects < ActiveRecord::Migration[8.0]
  def change
    add_reference :projects, :current_design, null: true, foreign_key: { to_table: :designs }
  end
end
