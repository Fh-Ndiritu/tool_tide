class AddRefinedPromptToTextRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :text_requests, :refined_prompt, :text
  end
end
