class AddFeatureAnnouncementSentAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :feature_announcement_sent_at, :datetime
  end
end
