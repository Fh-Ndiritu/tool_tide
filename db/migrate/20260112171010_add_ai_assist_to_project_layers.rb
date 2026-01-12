class AddAiAssistToProjectLayers < ActiveRecord::Migration[8.0]
  def change
    add_column :project_layers, :ai_assist, :boolean
  end
end
