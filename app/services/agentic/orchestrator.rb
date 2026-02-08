module Agentic
  class Orchestrator
    # The persona and instructions for the agent
    SYSTEM_PROMPT = <<~PROMPT
      You are a world-class Creative Director and Architect specializing in high-fidelity sketch-to-render transformations.
      Your objective is to transform sketches into polished designs while PRESERVING EVERY DETAIL from the original.

      You have access to these tools:
      - `Agentic::AnalyzeTool`: Analyzes the original sketch to extract a detailed inventory of ALL elements. USE THIS FIRST.
      - `Agentic::InpaintTool`: Transforms an image based on a prompt. Use for main transformation and refinements.
      - `Agentic::CompareTool`: Compares transformed result against original to identify discrepancies. USE AFTER EACH TRANSFORMATION.
      - `Agentic::UpscaleTool`: Upscales the final result to high resolution. USE ONLY AT THE END.

      MANDATORY WORKFLOW - FOLLOW EXACTLY:

      STEP 1 - ANALYZE:
      First, use AnalyzeTool to create a detailed inventory of ALL elements in the original sketch.
      This becomes your checklist for fidelity verification.

      STEP 2 - TRANSFORM:
      Use InpaintTool with a comprehensive prompt that EXPLICITLY LISTS all elements to preserve.
      Your prompt must reference the analysis and include every identified element.

      STEP 3 - COMPARE:
      Use CompareTool to check the transformation against the original.
      Look for: missing elements, incorrect elements, added elements, composition issues.

      STEP 4 - REFINE (if needed):
      If CompareTool reports FIDELITY_ISSUES_FOUND:
      - Use InpaintTool again with a targeted prompt to fix SPECIFIC discrepancies
      - Focus on the exact elements that were missing or incorrect
      - MAXIMUM 3 refinement iterations - then you MUST move to upscale

      STEP 5 - UPSCALE (MANDATORY FINAL STEP):
      After max 3 refinements OR when CompareTool reports FIDELITY_PASSED:
      Use UpscaleTool to create the final high-resolution output.
      You MUST ALWAYS end with upscaling - this is non-negotiable.

      CRITICAL RULES:
      - NEVER skip the analysis step
      - ALWAYS compare after transformation
      - MAXIMUM 3 InpaintTool refinements - then STOP refining
      - ALWAYS end with UpscaleTool - never finish without upscaling
      - Be EXPLICIT about every element in your prompts
      - Prioritize fidelity over artistic interpretation

      STYLE GUIDELINES:
      - "Photorealistic": Realistic lighting, textures, materials, shadows, environmental details
      - "Clay Render": Monochromatic clay/grey material render showing pure form and volume
      - "ArchiCAD": Technical architectural visualization with clean lines
      - "Watercolor": Soft, artistic watercolor aesthetic with preserved structure
    PROMPT

    def initialize(project_layer, description, transformation_type, agentic_run_id = nil)
      @project_layer = project_layer
      @description = description # Optional context about what the sketch represents
      @transformation_type = transformation_type
      @agentic_run = AgenticRun.find_by(id: agentic_run_id)
      @user = @project_layer.project.user
    end

    def perform
      ensure_run_exists
      layer_id = @project_layer.id

      broadcast_log("[Layer #{layer_id}] Sketch transformation started", "text-blue-400")
      broadcast_log("[Layer #{layer_id}] Style: #{@transformation_type}", "text-blue-300")
      if @description.present?
        broadcast_log("[Layer #{layer_id}] Description: #{@description}", "text-gray-400")
      end
      Rails.logger.info("Agentic::Orchestrator starting for Layer #{layer_id} with style: #{@transformation_type}")

      if @agentic_run.cancelled?
        broadcast_log("[Layer #{layer_id}] Run cancelled by user.", "text-red-400")
        return
      end

      chat = CustomRubyLLM.context(model: "gemini-2.5-flash").chat
        .with_tools(
          Agentic::AnalyzeTool.new(@project_layer, transformation_type: @transformation_type, agentic_run: @agentic_run),
          Agentic::InpaintTool.new(@project_layer, transformation_type: @transformation_type, agentic_run: @agentic_run),
          Agentic::CompareTool.new(@project_layer, transformation_type: @transformation_type, agentic_run: @agentic_run),
          Agentic::UpscaleTool.new(@project_layer, transformation_type: @transformation_type, agentic_run: @agentic_run)
        )
        .with_instructions(system_message)

      # Build user message - emphasize the analyze-first workflow
      user_message = "Transform this sketch into a #{@transformation_type} style render with HIGH FIDELITY."
      if @description.present?
        user_message += " Context: #{@description}"
      end
      user_message += " IMPORTANT: Start by analyzing the sketch to inventory ALL elements, then transform, compare against original, refine if needed, and finally upscale."

      broadcast_log("Analyzing sketch...", "text-cyan-400")
      @agentic_run.running!

      # Increased iterations for analyze + transform + compare + refine + upscale workflow
      completed = false
      refinement_count = 0
      max_refinements = 3
      has_upscaled = false
      8.times do |i|
        # Reload to check for cancellation
        @agentic_run.reload
        if @agentic_run.cancelled?
          broadcast_log("[Layer #{layer_id}] Run cancelled.", "text-red-400")
          break
        end

        # Billing Check
        if !@user.can_afford_generation?("pro_mode", 1)
          @agentic_run.paused!
          broadcast_log("[Layer #{layer_id}] Paused: Insufficient credits.", "text-yellow-400")
          broadcast_low_credits_notification
          break
        end

        broadcast_log("[Layer #{layer_id}] Step #{i+1}/8: Processing...", "text-gray-300")

        # Check if we've hit the refinement limit - force upscale
        if refinement_count >= max_refinements && !has_upscaled
          broadcast_log("[Layer #{layer_id}] Max refinements reached - proceeding to upscale", "text-orange-400")
          user_message = "STOP REFINING. You have reached the maximum number of refinement iterations. Now use UpscaleTool to upscale the final result. DO NOT call InpaintTool again."
        end

        # Execute Chat
        # Note: In a real agent loop, we need to inspect the tool calls to deduct credits *after* execution
        # But RubyLLM abstracts this. We might need to wrap the tools or assume cost based on response.
        # For this implementation, we will charge per step if it likely involved generation,
        # or we verify if a new layer was created.

        # Let's count layers before and after to charge.
        layers_count_before = @project_layer.project.project_layers.count

        broadcast_log("[Layer #{layer_id}] Calling agent...", "text-cyan-400")
        response = chat.ask(user_message, with: @project_layer.display_image)

        # Debug: Log the full response object to understand its structure
        Rails.logger.info("Agent Step #{i} response class: #{response.class}")
        Rails.logger.info("Agent Step #{i} response inspect: #{response.inspect[0..500]}")

        # Store full response for debugging
        full_response = response.content.to_s
        Rails.logger.info("Agent Step #{i} full response:\n#{full_response}")

        # Store full agent thoughts in run logs
        store_agent_response(i, full_response)

        # Handle empty responses (common when tools are executed)
        if full_response.blank?
          broadcast_log("[Layer #{layer_id}] Agent executing tools...", "text-yellow-300")
        else
          # Truncate for UI display only
          response_preview = full_response.length > 200 ? "#{full_response[0..200]}..." : full_response
          broadcast_log("[Layer #{layer_id}] Agent: #{response_preview}", "text-green-300")
        end

        layers_count_after = @project_layer.project.project_layers.count
        new_layers = layers_count_after - layers_count_before

        if new_layers > 0
          broadcast_log("[Layer #{layer_id}] Created #{new_layers} new layer(s)", "text-purple-400")
        end

        # Check for tool usage indicators in response
        content_str = response.content.to_s
        if content_str.include?("AnalyzeTool") || content_str.include?("analyze")
          broadcast_log("[Layer #{layer_id}] ✓ Analysis complete", "text-cyan-300")
        end
        if content_str.include?("InpaintTool") || content_str.include?("generated") || content_str.include?("layer")
          broadcast_log("[Layer #{layer_id}] ✓ Transformation applied", "text-green-300")
        end
        if content_str.include?("CompareTool") || content_str.include?("compare") || content_str.include?("FIDELITY")
          broadcast_log("[Layer #{layer_id}] ✓ Comparison complete", "text-yellow-300")
        end
        if content_str.include?("UpscaleTool") || content_str.include?("upscale")
          broadcast_log("[Layer #{layer_id}] ✓ Upscale complete", "text-pink-300")
          has_upscaled = true
        end

        # Track InpaintTool calls for refinement limiting
        if new_layers > 0
          # Check if this was an InpaintTool call (not UpscaleTool)
          latest_layer = @project_layer.project.project_layers.order(created_at: :desc).first
          if latest_layer&.intermediate?
            refinement_count += 1
            broadcast_log("[Layer #{layer_id}] Refinement #{refinement_count}/#{max_refinements}", "text-blue-300")
          end
        end

        if response.content.to_s.downcase.include?("finished") ||
           response.content.to_s.downcase.include?("complete") ||
           response.content.to_s.downcase.include?("upscaled")
          broadcast_log("[Layer #{layer_id}] Agent indicates completion", "text-purple-400")
          completed = true
          @agentic_run.completed!
          break
        end

        user_message = "Proceed to the next step or finalize if satisfied."
      end

      # Ensure we mark as completed if we finished all iterations
      unless completed || @agentic_run.cancelled? || @agentic_run.paused? || @agentic_run.failed?
        @agentic_run.completed!
      end

      broadcast_log("[Layer #{layer_id}] Orchestrator finished. Status: #{@agentic_run.status}", "text-white")
      broadcast_button_reset
    rescue => e
      @agentic_run.failed!
      broadcast_log("Error: #{e.message}", "text-red-500")
      broadcast_button_reset
      Rails.logger.error(e)
    end

    private

    def ensure_run_exists
      return if @agentic_run

      @agentic_run = AgenticRun.create!(
        project: @project_layer.project,
        status: :pending,
        logs: []
      )
    end

    def system_message
      "#{SYSTEM_PROMPT}\n\nCurrent Tranformation Type: #{@transformation_type}"
    end

    def broadcast_log(message, color_class = "text-gray-400")
       log_entry = { timestamp: Time.current.iso8601, message: message, color: color_class }

       # Atomic update for logs is better, but simple append works for now
       logs = @agentic_run.logs || []
       logs << log_entry
       @agentic_run.update_column(:logs, logs)

       Turbo::StreamsChannel.broadcast_append_to(
        @agentic_run, # Broadcast to the specific run channel
        :sketch_logs,
        target: "sketch_logs_#{@agentic_run.id}",
        partial: "projects/tools/sketch_log_entry",
        locals: { entry: log_entry }
      )

       Turbo::StreamsChannel.broadcast_append_to(
        @project_layer.project,
        :sketch_logs,
        target: "sketch_logs",
        html: "<div class='#{color_class} mb-1'>[#{Time.current.strftime('%H:%M:%S')}] #{message}</div>"
      )
    end

    def store_agent_response(step_number, full_response)
      log_entry = {
        timestamp: Time.current.iso8601,
        type: "agent_response",
        step: step_number,
        content: full_response
      }

      logs = @agentic_run.logs || []
      logs << log_entry
      @agentic_run.update_column(:logs, logs)
    end

    def broadcast_button_reset
      Turbo::StreamsChannel.broadcast_replace_to(
        @project_layer.project,
        :sketch_logs,
        target: "sketch_start_button",
        partial: "projects/tools/sketch_start_button"
      )
    end

    def broadcast_low_credits_notification
      @user.reload
      Turbo::StreamsChannel.broadcast_append_to(
        @project_layer.project,
        :notifications,
        target: "project_notifications",
        partial: "projects/low_credits_notification",
        locals: { low_credits: true, credits_remaining: @user.pro_engine_credits }
      )
    end
  end
end
