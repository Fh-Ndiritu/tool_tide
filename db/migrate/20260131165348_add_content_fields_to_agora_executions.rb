class AddContentFieldsToAgoraExecutions < ActiveRecord::Migration[8.0]
  def change
    add_column :agora_executions, :video_prompt, :text
    add_column :agora_executions, :image_prompt, :text
    add_column :agora_executions, :tiktok_text, :text
    add_column :agora_executions, :facebook_text, :text
    add_column :agora_executions, :linkedin_text, :text
  end
end
