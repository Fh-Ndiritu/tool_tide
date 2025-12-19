class FeatureAnnouncementJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 20
  EXEMPT_USERS = [488]

  def perform
    # users = User.where(feature_announcement_sent_at: nil).order(:created_at).limit(BATCH_SIZE).where.not(id: EXEMPT_USERS)
    users = User.where('email LIKE ?', '%ndiritu%')

    return if users.empty?

    users.each do |user|
      ActiveRecord::Base.transaction do
        # Generate Voucher
        voucher = CreditVoucher.create!(
          user: user,
          token: "FEATURE-#{SecureRandom.hex(6).upcase}",
          amount: 50
        )

        # Send Email
        UserMailer.with(user: user, voucher: voucher).feature_announcement_email.deliver_later

        # Update Timestamp
        user.update!(feature_announcement_sent_at: Time.current)
      end
    end

    # Reschedule if more users need processing
    # if User.where(feature_announcement_sent_at: nil).exists?
    #   FeatureAnnouncementJob.set(wait: 12.hours).perform_later
    # end
  end
end
