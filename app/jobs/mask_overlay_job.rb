class MaskOverlayJob < ApplicationJob
  queue_as :default

  def perform(mask_request_id)
    mask_request = MaskRequest.find(mask_request_id)
    return if mask_request.overlay.attached?

    mask_request.resize_mask

    mask_request.overlaying!
    mask_request.overlay_mask
  end
end
