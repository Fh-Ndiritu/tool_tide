module Agora
  class Trend < ApplicationRecord
    include AgoraTable
    validates :period, presence: true

    # Broadcast new trends to dashboard sidebar
    after_create_commit -> {
      broadcast_prepend_to "agora_trends",
        target: "agora_trends_list",
        partial: "agora/trends/trend_item",
        locals: { trend: self }
      # Also update the Status HUD trend count
      broadcast_status_hud_update
    }

    private

    def broadcast_status_hud_update
      broadcast_replace_to "agora_status_hud",
        target: "agora_status_hud",
        partial: "agora/dashboard/status_hud"
    end
  end
end
