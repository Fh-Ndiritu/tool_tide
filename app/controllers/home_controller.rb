class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
        flash[:success] =  "Payment successful!"
  end
end
