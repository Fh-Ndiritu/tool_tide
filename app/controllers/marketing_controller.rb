# frozen_string_literal: true

class MarketingController < ApplicationController
  layout "application"  # Use unified application layout
  skip_before_action :authenticate_user!, raise: false
  before_action :set_seo_headers



  private

  def set_seo_headers
    response.set_header("X-Robots-Tag", "index, follow")
  end
end
