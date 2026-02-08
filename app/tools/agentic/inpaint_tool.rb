module Agentic
  class InpaintTool < RubyLLM::Tool
    description "Modifies a specific area of an image based on a prompt. For refinements, uses both original sketch and latest iteration for fidelity."

    param :prompt, type: :string, desc: "Detailed description of the visual changes to apply."
    param :mask, type: :string, desc: "Description or data of the area to modify (optional).", required: false

    def initialize(project_layer, transformation_type: nil, agentic_run: nil)
      @project_layer = project_layer
      @design = project_layer.design
      @transformation_type = transformation_type
      @agentic_run = agentic_run
    end

    def execute(prompt:, mask: nil)
      Rails.logger.info("Agentic::InpaintTool executing with prompt: #{prompt}")
      broadcast_progress("🖌️ I'm starting a transformation on your image...")

      user = @project_layer.user
      cost = TRANSFORM_ENGINE_COST

      # Pre-charge before API call
      spending = charge_user!(user, cost)

      # Get original sketch (always the first/original layer)
      original_layer = @design.project_layers.where(layer_type: :original).first || @project_layer
      original_blob = original_layer.display_image.blob

      # Get latest generated layer (if any) for refinements
      latest_generated = @design.project_layers.where(layer_type: :generated).order(created_at: :desc).first

      # For refinements: send both original + latest iteration
      # For initial transform: send only original
      response = if latest_generated
        Rails.logger.info("Agentic::InpaintTool refinement mode - using original + latest layer #{latest_generated.id}")
        broadcast_progress("🔄 I'm refining the [#{@transformation_type || 'photorealistic'}] render based on my previous work...")
        generate_image_with_reference(prompt, original_blob, latest_generated.display_image.blob)
      else
        Rails.logger.info("Agentic::InpaintTool initial transform mode - using original only")
        broadcast_progress("✨ I'm generating the initial [#{@transformation_type || 'photorealistic'}] transformation...")
        generate_image(prompt, original_blob)
      end

      if response[:success]
        broadcast_progress("💾 I'm saving the generated layer...")
        save_result(response[:data], response[:mime_type], spending)
      else
        # Refund on failure
        refund_user!(user, cost, spending)
        broadcast_progress("❌ Generation failed: #{response[:error]}", "text-red-400")
        "Error generating image: #{response[:error]}"
      end
    rescue => e
      # Refund on any exception
      refund_user!(user, cost, spending) if spending
      broadcast_progress("❌ Error: #{e.message}", "text-red-400")
      raise e
    end

    private

    # Initial transformation - single image input
    def generate_image(prompt, image_blob)
      conn = build_connection

      # Reinforce transformation type in prompt
      enhanced_prompt = <<~PROMPT
        TARGET STYLE: #{@transformation_type&.upcase || 'PHOTOREALISTIC'}

        #{prompt}

        CRITICAL: The output MUST be in #{@transformation_type || 'photorealistic'} style.
        Maintain this style consistently throughout the entire image.
      PROMPT

      payload = {
        "contents" => [
          {
            "parts" => [
              { "text" => enhanced_prompt },
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

      execute_request(conn, payload)
    end

    # Refinement - dual image input (original + latest iteration)
    def generate_image_with_reference(prompt, original_blob, latest_blob)
      conn = build_connection

      # Enhanced prompt with transformation type reinforcement
      refinement_prompt = <<~PROMPT
        TARGET STYLE: #{@transformation_type&.upcase || 'PHOTOREALISTIC'}

        #{prompt}

        CRITICAL INSTRUCTIONS:
        1. The output MUST be in #{@transformation_type || 'photorealistic'} style - DO NOT DEVIATE.
        2. The FIRST image is the ORIGINAL SKETCH - preserve all elements from it.
        3. The SECOND image is the CURRENT ITERATION - refine and improve it.
        4. Fix any fidelity issues while MAINTAINING the #{@transformation_type || 'photorealistic'} style.
        5. Do not change the style or aesthetic - only improve accuracy.
      PROMPT

      payload = {
        "contents" => [
          {
            "parts" => [
              { "text" => refinement_prompt },
              {
                "inline_data" => {
                  "mime_type" => original_blob.content_type,
                  "data" => Base64.strict_encode64(original_blob.download)
                }
              },
              {
                "inline_data" => {
                  "mime_type" => latest_blob.content_type,
                  "data" => Base64.strict_encode64(latest_blob.download)
                }
              }
            ]
          }
        ]
      }

      execute_request(conn, payload)
    end

    def build_connection
      Faraday.new(
        url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent",
        headers: {
          "Content-Type" => "application/json",
          "x-goog-api-key" => ENV["GEMINI_API_KEYS"].split("____").sample
        }
      ) do |f|
        f.options.timeout = 120
      end
    end

    def execute_request(conn, payload)
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
        { success: false, error: "API Error: #{response.status} - #{response.body}" }
      end
    rescue => e
      { success: false, error: e.message }
    end

    def save_result(data, mime_type, spending)
      # Get the latest layer in the design (could be result of a previous tool)
      source_layer = @design.project_layers.order(created_at: :desc).first || @project_layer

      extension = mime_type.split("/").last
      temp_file = Tempfile.new([ "sketch_inpaint", ".#{extension}" ], binmode: true)
      temp_file.write(data)
      temp_file.rewind

      new_layer = source_layer.project.project_layers.create!(
        parent: source_layer,
        design: source_layer.design,
        layer_type: :generated,
        generation_type: :intermediate,
        transformation_type: @transformation_type,
        progress: :complete
      )

      new_layer.image.attach(io: temp_file, filename: "sketch_inpaint.#{extension}", content_type: mime_type)

      # Update spending trackable to the new layer for better tracking
      spending.update!(trackable: new_layer) if spending

      RubyLLM::Content.new(
        "I have generated a new image based on your request. It is saved as layer #{new_layer.layer_number}."
      )
    end

    def charge_user!(user, cost)
      user.with_lock do
        if user.pro_engine_credits < cost
          raise "Insufficient credits"
        end

        user.pro_engine_credits -= cost
        user.save!

        CreditSpending.create!(
          user: user,
          amount: cost,
          transaction_type: :spend,
          trackable: @project_layer  # Will be updated to new_layer on success
        )
      end
    end

    def refund_user!(user, cost, spending)
      return unless spending

      user.with_lock do
        user.pro_engine_credits += cost
        user.save!

        CreditSpending.create!(
          user: user,
          amount: cost,
          transaction_type: :refund,
          trackable: spending.trackable
        )
      end

      Rails.logger.info("Agentic::InpaintTool refunded #{cost} credit(s) for layer #{@project_layer.id}")
    end

    def broadcast_progress(message, color_class = "text-yellow-300")
      log_entry = { timestamp: Time.current.iso8601, message: message, color: color_class }

      # Persist to agentic_run logs if available
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
