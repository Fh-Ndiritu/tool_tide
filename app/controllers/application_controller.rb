class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  before_action :set_active_storage_url_options
  before_action :authenticate_user!

  private

  def set_active_storage_url_options
    ActiveStorage::Current.url_options = { host: request.host, protocol: request.protocol.delete_suffix(':'), port: request.port }
  end
end
