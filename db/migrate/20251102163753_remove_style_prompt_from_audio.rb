class RemoveStylePromptFromAudio < ActiveRecord::Migration[8.0]
  def change
    remove_column :audios, :style_prompt
  end
end
