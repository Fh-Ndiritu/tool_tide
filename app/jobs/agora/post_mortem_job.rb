module Agora
  class PostMortemJob < ApplicationJob
    queue_as :low_priority

    def perform(execution_id)
      execution = Agora::Execution.find(execution_id)
      post = execution.post

      # 1. Gather Institutional Truth
      assembler = Agora::ContextAssemblyService.new
      context = assembler.assemble

      # 2. Reflection Session
      # We ask the "Lead Strategist" (Falcon/Head Hunter) to analyze the result.
      agent_config = AGORA_HEAD_HUNTER
      model_id = agent_config[:model_name]

      reflection = analyze_performance(post, execution, context, model_id)

      # 3. Store Learned Patterns
      # Expecting reflection to be JSON for structured storage
      if reflection.is_a?(Array)
        reflection.each do |insight|
          Agora::LearnedPattern.create!(
            source_execution: execution,
            pattern_type: insight["type"], # 'success' or 'failure'
            context_tag: insight["tag"],   # e.g., 'tiktok_hook'
            content: insight["content"],   # "Corporate hooks fail on TikTok."
            confidence: insight["confidence"] || 0.8
          )
        end
      else
        Rails.logger.warn("PostMortemJob: unstructured reflection received.")
      end
    end

    private

    def analyze_performance(post, execution, context, model_id)
      prompt = <<~PROMPT
        You are the "Master Strategist" conducting a Post-Mortem.

        CONTEXT:
        #{context}

        ORIGINAL IDEA:
        Title: #{post.title}
        Body: #{post.body}

        ACTUAL MARKET RESULT (METRICS):
        #{execution.metrics.to_json}

        TASK:
        1. Compare actual performance against general expectations using your intuition.
        2. Identify "Cognitive Errors" (why we failed) or "Success Patterns" (why we won).
        3. Output a strict JSON array of objects:
           - type: "success" or "failure"
           - tag: short context tag (e.g., "tiktok_visuals", "headline_copy")
           - content: The specific lesson learned (Max 1 sentence).
           - confidence: float 0.0-1.0 (How sure are you?)

        Example:
        [{"type": "failure", "tag": "tiktok_hook", "content": "Corporate b-roll causes immediate drop-off.", "confidence": 0.9}]
      PROMPT

      response = ::CustomRubyLLM.context(model: model_id).chat.ask(prompt)
      json_str = response.content.gsub(/```json/i, "").gsub(/```/, "").strip
      JSON.parse(json_str)
    rescue => e
      Rails.logger.warning("PostMortemJob failed: #{e.message}")
      puts "PostMortemJob ERROR: #{e.message}"
      []
    end
  end
end
