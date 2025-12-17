class AddTreatAsToCanvas < ActiveRecord::Migration[8.0]
  def change
    add_column :canvas, :treat_as, :integer
  end
end
