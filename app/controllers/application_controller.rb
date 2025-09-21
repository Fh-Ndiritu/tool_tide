# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  before_action :set_active_storage_url_options
  before_action :authenticate_user!

  def after_sign_in_path_for(resource)
    if resource.is_a?(User)
      new_canva_path
    else
      super
    end
  end

  private

  def set_active_storage_url_options
    ActiveStorage::Current.url_options = { host: request.host, protocol: request.protocol.delete_suffix(":"), port: request.port }
  end
end
