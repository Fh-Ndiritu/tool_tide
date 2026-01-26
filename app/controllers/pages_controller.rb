class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :privacy_policy ]

  def privacy_policy
  end
end
