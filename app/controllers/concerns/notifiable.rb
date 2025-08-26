# frozen_string_literal: true

module Notifiable
  extend ActiveSupport::Concern
  def handle_downgrade_notifications
    if current_user.reverted_to_free_engine && !current_user.notified_about_pro_credits
      current_user.update! notified_about_pro_credits: true
    end
  end
end
