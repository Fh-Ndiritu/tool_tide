class AddOriginalPromptToProjectLayers < ActiveRecord::Migration[8.0]
  def change
    add_column :project_layers, :original_prompt, :text
  end
end
