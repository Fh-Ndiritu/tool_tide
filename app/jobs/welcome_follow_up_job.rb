class WelcomeFollowUpJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    # Determine activity type
    # Priority: Mask -> Sketch -> Text -> None
    # We check if they have created any requests of these types

    activity_type = if user.mask_requests.any?
      :mask
    elsif user.sketch_requests.any?
      :text
    else
      :none
    end

    UserMailer.with(user: user, activity_type: activity_type).welcome_follow_up_email.deliver_now
  end
end
