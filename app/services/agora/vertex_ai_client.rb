# frozen_string_literal: true

require "ostruct"

module Agora
  # Client for Vertex AI Model Garden (MaaS) endpoints via OpenAPI interface
  # Uses Gcp::Client for authentication via service account
  class VertexAIClient
    def initialize(model_name:, publisher: "google", location: nil)
      @model_name = model_name
      @publisher = publisher
      @project_id = VERTEX_CONFIG[:project_id]

      # Use provided location or fallback to config default
      @location = location || VERTEX_CONFIG[:location]

      @gcp_client = Gcp::Client.new
    end

    # Mimic RubyLLM chat interface for consistency
    def chat
      self
    end

    def ask(prompt)
      endpoint = build_endpoint
      payload = build_payload(prompt)

      retries = 0
      begin
        Rails.logger.info("[VertexAIClient] Calling #{@model_name} in #{@location} (Attempt #{retries + 1})")

        response = @gcp_client.send(endpoint, payload)
        content = extract_content(response)

        # Attempt to parse content to ensure it's valid JSON
        # This will raise JSON::ParserError if invalid, triggering the rescue block
        validate_json!(content)

        OpenStruct.new(content: content)
      rescue JSON::ParserError => e
        retries += 1
        if retries <= 3
          Rails.logger.warn("[VertexAIClient] JSON Validation Failed for #{@model_name}: #{e.message}. Retrying... (#{retries}/3)")
          sleep 1
          retry
        else
          Rails.logger.error("[VertexAIClient] Failed to get valid JSON from #{@model_name} after 3 retries.")
          # Return the invalid content anyway so we can debug it, or raise?
          # User said "fail", so we let the exception bubble up or return invalid content.
          # For now, let's return the content but log the error,
          # or we simply re-raise the ParserError to fail the job hard.
          raise e
        end
      rescue => e
        Rails.logger.error("[VertexAIClient] Error for #{@model_name}: #{e.message}")
        raise e
      end
    end

    private

    def validate_json!(content)
      return if content.blank?
      JSON.parse(content)
    end

    def build_endpoint
      # Vertex AI MaaS OpenAPI format:
      # https://{location}-aiplatform.googleapis.com/v1/projects/{project}/locations/{location}/endpoints/openapi/chat/completions

      # Determine hostname based on location
      hostname = if @location == "global"
        "aiplatform.googleapis.com"
      else
        "#{@location}-aiplatform.googleapis.com"
      end

      "https://#{hostname}/v1/projects/#{@project_id}/locations/#{@location}/endpoints/openapi/chat/completions"
    end

    def build_payload(prompt)
      # OpenAI-compatible payload structure for MaaS
      # We append a system instruction to force pure JSON/content without commentary
      system_instruction = "You are a precise data processing assistant. Output ONLY the requested format (e.g., JSON) with NO introductory text, markdown formatting, or commentary."

      {
        "model" => @model_name,
        "messages" => [
          { "role" => "system", "content" => system_instruction },
          { "role" => "user", "content" => prompt }
        ],
        "temperature" => 0.5,
        "max_tokens" => 2048,
        "stream" => false,
        "response_format" => { "type" => "json_object" }
      }
    end

    def extract_content(response)
      # OpenAI-compatible response format:
      # { "choices": [{ "message": { "content": "..." } }] }
      choices = response["choices"] || []
      return "" if choices.empty?

      content = choices.first.dig("message", "content") || ""

      # Aggressively strip thinking process for reasoning models
      # Use .last to take everything after the final </think> tag
      if content.include?("</think>")
        content = content.split("</think>").last.strip
      end

      # Robust JSON extraction: Find first '{' and last '}'
      # This bypasses any markdown framing or conversational filler
      first_brace = content.index("{")
      last_brace = content.rindex("}")

      if first_brace && last_brace && last_brace >= first_brace
        content[first_brace..last_brace]
      else
        # Fallback cleaning if no braces found
        content.strip.sub(/^```json\s*/i, "").sub(/^```\s*/, "").sub(/```$/, "").strip
      end
    end
  end
end
