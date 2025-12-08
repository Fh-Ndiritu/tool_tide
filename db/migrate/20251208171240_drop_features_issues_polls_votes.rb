class DropFeaturesIssuesPollsVotes < ActiveRecord::Migration[8.0]
  def change
    drop_table :polls, if_exists: true
    drop_table :votes, if_exists: true
    drop_table :features, if_exists: true
    drop_table :issues, if_exists: true
  end
end
