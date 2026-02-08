class AddPlatformFieldsToAgoraExecutions < ActiveRecord::Migration[8.0]
  def change
    add_column :agora_executions, :instagram_text, :text
    add_column :agora_executions, :pinterest_text, :text
    add_column :agora_executions, :twitter_text, :text
    add_column :agora_executions, :youtube_description, :text
  end
end
