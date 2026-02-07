module Agentic
  class AnalyzeTool < RubyLLM::Tool
    description "Analyzes a sketch image to extract a detailed inventory of all visual elements. Returns a structured list of elements that must be preserved during transformation."

    param :focus_areas, type: :string, desc: "Optional specific areas or elements to focus the analysis on.", required: false

    def initialize(project_layer)
      @project_layer = project_layer
    end

    def execute(focus_areas: nil)
      Rails.logger.info("Agentic::AnalyzeTool executing")

      image_blob = @project_layer.display_image.blob
      analysis = analyze_sketch(image_blob, focus_areas)

      if analysis[:success]
        RubyLLM::Content.new(analysis[:content])
      else
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
        Analyze this sketch in detail and provide a comprehensive inventory of ALL visual elements.

        For each element, identify:
        1. Type (building, pool, path, tree, furniture, vehicle, person, etc.)
        2. Location (top-left, center, bottom-right, etc.)
        3. Size (large, medium, small relative to image)
        4. Key characteristics (shape, orientation, distinctive features)

        Be extremely thorough - every element matters for fidelity.

        #{focus_areas.present? ? "Focus especially on: #{focus_areas}" : ""}

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
  end
end
