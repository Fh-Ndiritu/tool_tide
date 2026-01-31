class AddVoterTypeToAgoraVotes < ActiveRecord::Migration[8.0]
  def change
    add_column :agora_votes, :voter_type_str, :string, default: "Agent"
    # Note: 'voter_type' is reserved by polymorphic associations if we had one.
    # But here 'voter_id' is just a string/int.
    # To avoid confusion with Rails conventions, I'll name it explicitly or check if I can use 'voter_type'.
    # Actually, standard polymorphic is `voter_type` and `voter_id`.
    # But here `voter_id` is a string (Agent Name) or Integer (User ID).
    # So `voter_type` string is fine to distinguish "Agent" vs "Human".
  end
end
