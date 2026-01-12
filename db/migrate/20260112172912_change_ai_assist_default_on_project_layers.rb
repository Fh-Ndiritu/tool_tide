class ChangeAiAssistDefaultOnProjectLayers < ActiveRecord::Migration[8.0]
  def change
    change_column_default :project_layers, :ai_assist, from: nil, to: false
  end
end
