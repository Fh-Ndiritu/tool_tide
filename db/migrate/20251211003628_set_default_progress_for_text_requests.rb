class SetDefaultProgressForTextRequests < ActiveRecord::Migration[8.0]
  def change
    change_column_default :text_requests, :progress, from: nil, to: 0
  end
end
