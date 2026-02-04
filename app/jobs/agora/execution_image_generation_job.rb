module Agora
  class ExecutionImageGenerationJob < ApplicationJob
    queue_as :default

    def perform(execution_id)
      execution = Agora::Execution.find(execution_id)
      return if execution.image_prompt.blank?

      broadcast_system_status("🎨 Generating Image for Execution ##{execution.id}...")

      # Use the existing ImageGenerator service
      image_blob = SocialMedia::ImageGenerator.perform(execution.image_prompt)

      if image_blob
        execution.images.attach(
          io: image_blob,
          filename: "agora_execution_#{execution.id}_#{Time.current.to_i}.png",
          content_type: "image/png"
        )
        broadcast_system_status("✅ Image Attached to Execution ##{execution.id}")
      else
        Rails.logger.error("[ExecutionImageGenerationJob] Failed to generate image for Execution ##{execution.id}")
        broadcast_system_status("❌ Image Generation Failed")
      end
    rescue => e
      Rails.logger.error("[ExecutionImageGenerationJob] Error: #{e.message}")
      broadcast_system_status("❌ Error Generating Image")
    end
  end
end
