class CompetitorsController < ApplicationController
  skip_before_action :authenticate_user!, only: :ojus
  def ojus
    # Ojus AI competitor comparison page
  end
end
