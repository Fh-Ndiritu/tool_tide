class PagesController < ApplicationController
  skip_before_action :authenticate_user!
  def privacy_policy
  end

  def contact_us
  end

  def full_faq
  end
end
