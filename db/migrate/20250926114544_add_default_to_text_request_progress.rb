class AddDefaultToTextRequestProgress < ActiveRecord::Migration[8.0]
  def change
    change_column_default :text_requests, :progress, to: 0
  end
end
