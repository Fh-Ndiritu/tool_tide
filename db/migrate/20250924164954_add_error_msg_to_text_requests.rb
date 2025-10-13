class AddErrorMsgToTextRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :text_requests, :error_msg, :string
  end
end
