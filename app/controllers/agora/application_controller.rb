module Agora
  class ApplicationController < ::AppController
    layout "agora/application"
    before_action :ensure_admin_access

    private

    def ensure_admin_access
      unless current_user&.admin?
        redirect_to main_app.root_path, alert: "Access Denied."
      end
    end
  end
end
