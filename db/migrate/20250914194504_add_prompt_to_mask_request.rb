class AddPromptToMaskRequest < ActiveRecord::Migration[8.0]
  def change
    add_column :mask_requests, :prompt, :text
  end
end
