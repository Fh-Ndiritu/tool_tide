class FeatureAnnouncementJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 40
  EXEMPT_USERS = [ 488 ]

  def perform
    # Users signed up before Feb 7, 2026, and have no stripe_customer_id
    cutoff_date = Date.new(2026, 2, 7)
    users = User.where(feature_announcement_sent_at: nil)
                .where(stripe_customer_id: nil)
                .where("created_at < ?", cutoff_date)
                .where.not(id: EXEMPT_USERS)
                .order(:created_at)
                .limit(BATCH_SIZE)

    return if users.empty?

    users.each do |user|
      ActiveRecord::Base.transaction do
        # Send Email
        UserMailer.with(user: user).stripe_announcement_email.deliver_later

        # Update Timestamp
        user.update!(feature_announcement_sent_at: Time.current)
      end
    end

    # Reschedule if more users need processing
    if User.where(feature_announcement_sent_at: nil).exists?
      FeatureAnnouncementJob.set(wait: 6.hours).perform_later
    end
  end
end
