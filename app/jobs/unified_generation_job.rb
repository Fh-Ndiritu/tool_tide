class UnifiedGenerationJob < ApplicationJob
  queue_as :default

  def perform(layer)
    return unless layer.is_a?(ProjectLayer)

    # Reload to ensure we have fresh state (though job args are usually fresh or GlobalID ref)
    # ActiveJob serializes models as GlobalID, so 'layer' is already a fresh record finding.

    layer.status_processing!

    begin
      UnifiedGenerator.perform(layer.id)
      layer.status_completed!
    rescue StandardError => e
      Rails.logger.error("UnifiedGenerationJob Failed for Layer #{layer.id}: #{e.message}")
      layer.status_failed!
      raise e # Re-raise to ensure job failure is tracked/retried if configured
    end
  end
end
