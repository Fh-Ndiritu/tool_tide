class AddErrorMsgToAudio < ActiveRecord::Migration[8.0]
  def change
    add_column :audios, :error_msg, :string
  end
end
