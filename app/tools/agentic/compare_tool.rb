module Agentic
  class CompareTool < RubyLLM::Tool
    description "Compares a transformed image against the original sketch to identify missing or incorrect elements. Returns a discrepancy report with specific items that need to be fixed."

    param :note, type: :string, desc: "Optional note about what to focus the comparison on.", required: false

    def initialize(project_layer, transformation_type: nil, agentic_run: nil)
      @project_layer = project_layer
      @design = project_layer.design
      @transformation_type = transformation_type
      @agentic_run = agentic_run
    end

    def execute(note: nil)
      Rails.logger.info("Agentic::CompareTool executing")
      broadcast_progress("🔍 I'm comparing the result against your original sketch...")

      # Get original sketch (the initial layer)
      original_layer = @design.project_layers.where(layer_type: :original).first || @project_layer

      # Get the latest transformed layer
      latest_layer = @design.project_layers.where(layer_type: :generated).order(created_at: :desc).first

      unless latest_layer
        broadcast_progress("⚠️ I don't see a transformed image to compare yet.", "text-orange-400")
        return "No transformed image found to compare. Please run a transformation first."
      end

      original_blob = original_layer.display_image.blob
      transformed_blob = latest_layer.display_image.blob

      comparison = compare_images(original_blob, transformed_blob, note)

      if comparison[:success]
        broadcast_progress("✅ I've finished my comparison review.", "text-yellow-300")
        RubyLLM::Content.new(comparison[:content])
      else
        broadcast_progress("❌ I couldn't complete the comparison: #{comparison[:error]}", "text-red-400")
        "Error comparing images: #{comparison[:error]}"
      end
    end

    private

    def compare_images(original_blob, transformed_blob, note)
      conn = Faraday.new(
        url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
        headers: {
          "Content-Type" => "application/json",
          "x-goog-api-key" => ENV["GEMINI_API_KEYS"].split("____").sample
        }
      ) do |f|
        f.options.timeout = 90
      end

      comparison_prompt = <<~PROMPT
        TARGET STYLE: #{@transformation_type&.upcase || 'PHOTOREALISTIC'}

        Compare these two images: the FIRST is the original sketch, the SECOND is the transformed result.

        Identify ALL discrepancies between the original sketch and the transformation:

        1. MISSING ELEMENTS: What exists in the original but is absent in the transformation?
        2. INCORRECT ELEMENTS: What was transformed incorrectly (wrong shape, position, style)?
        3. ADDED ELEMENTS: What was added that doesn't exist in the original?
        4. COMPOSITION ISSUES: Any layout or spatial relationship problems?
        5. STYLE CONSISTENCY: Does the result maintain #{@transformation_type || 'photorealistic'} style throughout?
           - Is the style consistent across the entire image?
           - Are materials, lighting, and textures appropriate for #{@transformation_type || 'photorealistic'} rendering?

        #{note.present? ? "Special focus: #{note}" : ""}

        For each issue, provide:
        - Element name and location
        - What's wrong
        - Specific fix needed (while MAINTAINING #{@transformation_type || 'photorealistic'} style)

        CRITICAL: Any refinement suggestions must preserve the #{@transformation_type || 'photorealistic'} style.
        DO NOT suggest changes that would alter the style.

        If the transformation is faithful to the original with consistent #{@transformation_type || 'photorealistic'} styling,
        state "FIDELITY_PASSED" at the start of your response.
        Otherwise, start with "FIDELITY_ISSUES_FOUND" followed by the detailed list.
      PROMPT

      payload = {
        "contents" => [
          {
            "parts" => [
              { "text" => comparison_prompt },
              {
                "inline_data" => {
                  "mime_type" => original_blob.content_type,
                  "data" => Base64.strict_encode64(original_blob.download)
                }
              },
              {
                "inline_data" => {
                  "mime_type" => transformed_blob.content_type,
                  "data" => Base64.strict_encode64(transformed_blob.download)
                }
              }
            ]
          }
        ]
      }

      response = conn.post("", payload.to_json)

      if response.success?
        json = JSON.parse(response.body)
        content = json.dig("candidates", 0, "content", "parts", 0, "text")

        if content
          { success: true, content: content }
        else
          { success: false, error: "No comparison content in response" }
        end
      else
        { success: false, error: "API Error: #{response.status} - #{response.body}" }
      end
    rescue => e
      { success: false, error: e.message }
    end

    def broadcast_progress(message, color_class = "text-yellow-300")
      log_entry = { timestamp: Time.current.iso8601, message: message, color: color_class }

      if @agentic_run
        logs = @agentic_run.logs || []
        logs << log_entry
        @agentic_run.update_column(:logs, logs)
      end

      Turbo::StreamsChannel.broadcast_append_to(
        @project_layer.project,
        :sketch_logs,
        target: "sketch_logs",
        html: "<div class='#{color_class} mb-1'>[#{Time.current.strftime('%H:%M:%S')}] #{message}</div>"
      )
    end
  end
end
