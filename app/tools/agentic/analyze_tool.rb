module Agentic
  class AnalyzeTool < RubyLLM::Tool
    description "Analyzes a sketch image to extract a detailed inventory of all visual elements. Returns a structured list of elements that must be preserved during transformation."

    param :focus_areas, type: :string, desc: "Optional specific areas or elements to focus the analysis on.", required: false

    def initialize(project_layer, transformation_type: nil, agentic_run: nil)
      @project_layer = project_layer
      @transformation_type = transformation_type
      @agentic_run = agentic_run
    end

    def execute(focus_areas: nil)
      Rails.logger.info("Agentic::AnalyzeTool executing")
      broadcast_progress("🔍 Let me analyze your sketch and identify all elements...")

      image_blob = @project_layer.display_image.blob
      analysis = analyze_sketch(image_blob, focus_areas)

      if analysis[:success]
        broadcast_progress("✅ I've catalogued all the elements in your sketch.", "text-cyan-300")
        RubyLLM::Content.new(analysis[:content])
      else
        broadcast_progress("❌ I couldn't analyze the sketch: #{analysis[:error]}", "text-red-400")
        "Error analyzing sketch: #{analysis[:error]}"
      end
    end

    private

    def analyze_sketch(image_blob, focus_areas)
      conn = Faraday.new(
        url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
        headers: {
          "Content-Type" => "application/json",
          "x-goog-api-key" => ENV["GEMINI_API_KEYS"].split("____").sample
        }
      ) do |f|
        f.options.timeout = 60
      end

      analysis_prompt = <<~PROMPT
        TARGET STYLE: #{@transformation_type&.upcase || 'PHOTOREALISTIC'}

        Analyze this sketch in detail and provide a comprehensive inventory of ALL visual elements.

        For each element, identify:
        1. Type (building, pool, path, tree, furniture, vehicle, person, etc.)
        2. Location (top-left, center, bottom-right, etc.)
        3. Size (large, medium, small relative to image)
        4. Key characteristics (shape, orientation, distinctive features)
        5. How it should look in #{@transformation_type || 'photorealistic'} style

        Be extremely thorough - every element matters for fidelity.

        #{focus_areas.present? ? "Focus especially on: #{focus_areas}" : ""}

        IMPORTANT: The target style is #{@transformation_type || 'photorealistic'}. Note any elements
        that require special treatment to achieve this style (lighting, materials, textures).

        Format your response as a structured list that can be used as a checklist during transformation verification.
      PROMPT

      payload = {
        "contents" => [
          {
            "parts" => [
              { "text" => analysis_prompt },
              {
                "inline_data" => {
                  "mime_type" => image_blob.content_type,
                  "data" => Base64.strict_encode64(image_blob.download)
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
          { success: false, error: "No analysis content in response" }
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
