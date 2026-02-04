# frozen_string_literal: true

class AppController < ApplicationController
  before_action :authenticate_user!, unless: :devise_controller?

  layout "application"

  private
end
