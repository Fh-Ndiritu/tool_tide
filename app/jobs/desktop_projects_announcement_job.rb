class DesktopProjectsAnnouncementJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 30

  def perform
    # Find users who haven't received the announcement yet
    # Order by created_at DESC to start with most recent users
    users = User.where(desktop_projects_announcement_sent_at: nil)
                .order(created_at: :desc)
                .limit(BATCH_SIZE)

    return if users.empty?

    users.each do |user|
      ActiveRecord::Base.transaction do
        # Send Email
        UserMailer.with(user: user).desktop_projects_announcement_email.deliver_later

        # Update Timestamp to mark as sent
        user.update!(desktop_projects_announcement_sent_at: Time.current)
      end
    end

    # Reschedule if more users need processing
    if User.where(desktop_projects_announcement_sent_at: nil).exists?
      DesktopProjectsAnnouncementJob.set(wait: 12.hours).perform_later
    end
  end
end
