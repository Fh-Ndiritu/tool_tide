class PlantingGuideJob < ApplicationJob
  queue_as :default

  def perform(mask_request_id)
    mask_request = MaskRequest.find(mask_request_id)
    DesignGenerator.new(mask_request).generate_planting_guide

    Turbo::StreamsChannel.broadcast_replace_to(
      mask_request.canva,
      target: "planting_guide_section",
      partial: "mask_requests/planting_guide_section",
      locals: { mask_request: mask_request }
    )
    mask_request.complete!
  end
end
