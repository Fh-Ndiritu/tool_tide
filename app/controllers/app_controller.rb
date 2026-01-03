# frozen_string_literal: true

class AppController < ApplicationController
  before_action :authenticate_user!, unless: :devise_controller?
  before_action :block_crawlers

  layout "application"

  private

  def block_crawlers
    response.set_header("X-Robots-Tag", "noindex, nofollow, noarchive")
  end
end
