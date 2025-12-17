class AddUserIdToSketchRequests < ActiveRecord::Migration[8.0]
  def up
    add_reference :sketch_requests, :user, null: true, foreign_key: true

    # Backfill
    SketchRequest.reset_column_information
    SketchRequest.find_each do |sr|
      sr.update_column(:user_id, sr.canva.user_id) if sr.canva
    end

    change_column_null :sketch_requests, :user_id, false
  end

  def down
    remove_reference :sketch_requests, :user
  end
end
