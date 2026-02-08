module Agora
  class ExecutionImageGenerationJob < ApplicationJob
    queue_as :default

    GEMINI_IMAGE_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent".freeze

    def perform(execution_id)
      execution = Agora::Execution.find(execution_id)
      return if execution.image_prompt.blank?

      broadcast_system_status("🎨 Generating Image for Execution ##{execution.id}...")

      # Get platform-specific aspect ratio
      aspect_info = aspect_ratio_for_platform(execution.platform)

      # Enhanced prompt for high-quality marketing images with platform-specific aspect ratio
      enhanced_prompt = <<~PROMPT
        Generate a high-quality, 4K resolution, photorealistic marketing image.

        CRITICAL ASPECT RATIO REQUIREMENT:
        - Generate this image in #{aspect_info[:ratio]} aspect ratio (#{aspect_info[:description]})
        - This is for #{execution.platform.presence || 'social media'}, so the aspect ratio is MANDATORY

        IMAGE REQUIREMENTS:
        - Professional, premium aesthetic suitable for social media marketing
        - High resolution, sharp details, excellent lighting
        - Minimal or no text overlays (text reduces image quality)
        - Clean, visually striking composition

        CREATIVE DIRECTION:
        #{execution.image_prompt}
      PROMPT

      response = generate_with_gemini(enhanced_prompt)

      if response[:success]
        execution.images.attach(
          io: StringIO.new(response[:data]),
          filename: "agora_execution_#{execution.id}_#{Time.current.to_i}.png",
          content_type: response[:mime_type]
        )
        broadcast_system_status("✅ Image Attached to Execution ##{execution.id}")

        # Broadcast the updated image slider to the view
        Turbo::StreamsChannel.broadcast_replace_to(
          "agora_execution_#{execution.id}",
          target: "image_generation_#{execution.id}",
          partial: "agora/executions/image_section",
          locals: { execution: execution }
        )
      else
        Rails.logger.error("[ExecutionImageGenerationJob] Failed: #{response[:error]}")
        broadcast_system_status("❌ Image Generation Failed: #{response[:error]}")
      end
    rescue => e
      Rails.logger.error("[ExecutionImageGenerationJob] Error: #{e.message}")
      broadcast_system_status("❌ Error Generating Image: #{e.message}")
    end

    private

    def generate_with_gemini(prompt)
      conn = Faraday.new(
        url: GEMINI_IMAGE_URL,
        headers: {
          "Content-Type" => "application/json",
          "x-goog-api-key" => ENV["GEMINI_API_KEYS"].split("____").sample
        }
      ) do |f|
        f.options.timeout = 120
      end

      payload = {
        "contents" => [
          {
            "parts" => [
              { "text" => prompt }
            ]
          }
        ]
      }

      response = conn.post("", payload.to_json)

      if response.success?
        json = JSON.parse(response.body)
        candidate = json.dig("candidates", 0, "content", "parts", 0, "inlineData")

        if candidate
          { success: true, data: Base64.decode64(candidate["data"]), mime_type: candidate["mimeType"] }
        else
          { success: false, error: "No image data in response" }
        end
      else
        { success: false, error: "API Error: #{response.status}" }
      end
    rescue => e
      { success: false, error: e.message }
    end

    # Platform-specific aspect ratios (Gemini 3 Pro supported: 1:1, 2:3, 3:2, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9)
    PLATFORM_ASPECT_RATIOS = {
      "tiktok" => { ratio: "9:16", description: "vertical/portrait for full-screen mobile" },
      "instagram" => { ratio: "4:5", description: "portrait for feed" },
      "facebook" => { ratio: "1:1", description: "square for feed" },
      "linkedin" => { ratio: "16:9", description: "landscape for feed" },
      "pinterest" => { ratio: "2:3", description: "vertical/portrait for pins" },
      "twitter" => { ratio: "16:9", description: "landscape for timeline" },
      "youtube" => { ratio: "16:9", description: "landscape for thumbnails" }
    }.freeze

    def aspect_ratio_for_platform(platform)
      normalized = platform.to_s.downcase.strip
      PLATFORM_ASPECT_RATIOS[normalized] || { ratio: "1:1", description: "square (universal fallback)" }
    end
  end
end
