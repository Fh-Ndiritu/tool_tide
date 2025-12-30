class UnifiedGenerationJob < ApplicationJob
  queue_as :default

  def perform(layer_ids)
    layers = ProjectLayer.where(id: layer_ids)

    layers.each do |layer|
      # Simulate processing time
      sleep 2

      # In a real scenario, this would call an AI Service.
      # For now, we will just log it.
      # Ideally we should attach a dummy image if we had one, but strict file access prevents me from grabbing a random one easily without knowing paths.
      # So we will just print to stdout which is captured in logs.

      Rails.logger.info "UnifiedGenerationJob: Processed Layer #{layer.id} with prompt: '#{layer.prompt}' and preset: '#{layer.preset}'"
    end
  end
end
