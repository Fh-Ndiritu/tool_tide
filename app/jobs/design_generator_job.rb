class DesignGeneratorJob < ApplicationJob
  queue_as :default

  def perform(id)
    mask_request = MaskRequest.find(id)

    if !mask_request.mask.attached?
      mask_request.reload
    end

    if mask_request.mask.attached?
      DesignGenerator.perform(mask_request)
    else
      mask_request.update!(progress: :failed, user_error: "Drawing is not present! Please try again.")
    end
  end
end
