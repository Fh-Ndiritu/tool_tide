class AutoFixDetectionJob < ApplicationJob
  queue_as :default

  def perform(layer_id)
    layer = ProjectLayer.find_by(id: layer_id)
    return unless layer

    # Broadcast that we are starting analysis
    broadcast_status(layer, "Analyzing landscape...")

    # Perform analysis
    AutoFixDetectorService.perform(layer)

    # Broadcast results
    broadcast_results(layer)
  rescue StandardError => e
    Rails.logger.error("AutoFixDetectionJob Error: #{e.message}")
    broadcast_status(layer, "Analysis failed. Please try again.")
  end

  private

  def broadcast_status(layer, message)
    Turbo::StreamsChannel.broadcast_update_to(
      layer.design, :layers,
      target: "auto_fix_results",
      html: render_status(message)
    )
  end

  def broadcast_results(layer)
    auto_fixes = layer.auto_fixes.pending

    Turbo::StreamsChannel.broadcast_update_to(
      layer.design, :layers,
      target: "auto_fix_results",
      partial: "auto_fixes/auto_fix_list",
      locals: { auto_fixes: auto_fixes, project_layer: layer },
      formats: [:html]
    )
  end

  def render_status(message)
    ApplicationController.render(
      partial: "auto_fixes/loading_state",
      locals: { message: message },
      formats: [:html]
    )
  end
end
