# frozen_string_literal: true

class MarketingController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  before_action :set_seo_headers

  layout "marketing"

  private

  def set_seo_headers
    response.set_header("X-Robots-Tag", "index, follow")
  end
end
