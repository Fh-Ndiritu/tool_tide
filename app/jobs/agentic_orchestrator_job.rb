class AgenticOrchestratorJob < ApplicationJob
  queue_as :default

  def perform(project_layer_id, goal, transformation_type, agentic_run_id = nil)
    project_layer = ProjectLayer.find_by(id: project_layer_id)
    return unless project_layer

    # Broadcast start
    Turbo::StreamsChannel.broadcast_append_to(
      project_layer.project,
      :sketch_logs,
      target: "sketch_logs",
      html: "<div class='text-yellow-400'>[System] Job started for layer #{project_layer.id}...</div>"
    )

    # Run Orchestrator
    Agentic::Orchestrator.new(project_layer, goal, transformation_type, agentic_run_id).perform

    # Broadcast finish
    Turbo::StreamsChannel.broadcast_append_to(
      project_layer.project,
      :sketch_logs,
      target: "sketch_logs",
      html: "<div class='text-green-400'>[System] Job finished.</div>"
    )
  rescue => e
    Turbo::StreamsChannel.broadcast_append_to(
      project_layer.project,
      :sketch_logs,
      target: "sketch_logs",
      html: "<div class='text-red-500'>[System] Error: #{e.message}</div>"
    )
    raise e
  end
end
