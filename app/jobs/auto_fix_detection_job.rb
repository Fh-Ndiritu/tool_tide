class AutoFixDetectionJob < ApplicationJob
  queue_as :generation

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
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    broadcast_error(layer, "Analysis failed. Please try again.")
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

    if auto_fixes.any?
      Turbo::StreamsChannel.broadcast_update_to(
        layer.design, :layers,
        target: "auto_fix_results",
        partial: "auto_fixes/auto_fix_list",
        locals: { auto_fixes: auto_fixes, project_layer: layer },
        formats: [ :html ]
      )
    else
      Turbo::StreamsChannel.broadcast_update_to(
        layer.design, :layers,
        target: "auto_fix_results",
        html: render_empty_state(layer)
      )
    end
  end

  def render_empty_state(layer)
    ApplicationController.render(
      partial: "auto_fixes/empty_state",
      locals: { project_layer: layer },
      formats: [ :html ]
    )
  end

  def render_status(message)
    ApplicationController.render(
      partial: "auto_fixes/loading_state",
      locals: { message: message },
      formats: [ :html ]
    )
  end

  def broadcast_error(layer, message)
    Turbo::StreamsChannel.broadcast_update_to(
      layer.design, :layers,
      target: "auto_fix_results",
      html: render_error_state(layer, message)
    )
  end

  def render_error_state(layer, message)
    ApplicationController.render(
      partial: "auto_fixes/error_state",
      locals: { project_layer: layer, message: message },
      formats: [ :html ]
    )
  end
end
