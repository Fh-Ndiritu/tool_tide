class ChangeTransformationTypeToStringInProjectLayers < ActiveRecord::Migration[8.0]
  def up
    # Clear any existing integer values that don't make sense as strings
    execute "UPDATE project_layers SET transformation_type = NULL WHERE transformation_type IS NOT NULL"
    change_column :project_layers, :transformation_type, :string
  end

  def down
    change_column :project_layers, :transformation_type, :integer
  end
end
