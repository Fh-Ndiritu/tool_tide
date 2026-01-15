class AddDesktopProjectsAnnouncementToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :desktop_projects_announcement_sent_at, :datetime
  end
end
