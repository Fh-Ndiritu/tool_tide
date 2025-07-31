class AddPromptToLandscapeRequest < ActiveRecord::Migration[8.0]
  def change
    add_column :landscape_requests, :prompt, :text
    remove_column :landscapes, :prompt
  end
end
