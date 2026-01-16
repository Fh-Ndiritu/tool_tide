class SmartFixImprover
  class RecommendationSchema < RubyLLM::Schema
    string :optimized_prompt, description: "The professionally refined version of the user's request, optimized for an AI Landscape Generator."
  end

  def initialize(project_layer, has_mask: false)
    @layer = project_layer
    @has_mask = has_mask
  end

  def self.perform(project_layer, has_mask: false)
    new(project_layer, has_mask: has_mask).optimize
  end

  def optimize
    return unless @layer.prompt.present?

    # Construct the meta-prompt based on mask presence
    system_prompt = if @has_mask
      <<~PROMPT
        You are a professional Prompt Engineer for Landscape Architecture AI.
        The user has highlighted a specific area of the image (violet mask) they want to modify.
        Your task is to refine their request into a detailed prompt specifically for that area.
        Focus on how the changes interact with the surrounding environment.
        Maintain the user's intent but ensure the prompt is robust for inpainting.
      PROMPT
    else
      <<~PROMPT
        You are a professional Prompt Engineer for Landscape Architecture AI.
        The user wants to modify the entire image (no specific mask).
        Your task is to refine their request into a detailed, high-fidelity prompt for the whole scene.
        Focus on aesthetics, lighting, texture, and botanical accuracy.
        Maintain the user's original intent but expand on the details.
      PROMPT
    end

    user_input = @layer.prompt

    # Call RubyLLM with Image Context
    # Downsize image to max 600px to optimize performance and reduce latency
    image_context = @layer.overlay.variant(resize_to_limit: [600, 600]).processed

    full_prompt = "#{system_prompt}\n\nRefine this request: #{user_input}"

    response = CustomRubyLLM.context.chat.with_schema(RecommendationSchema).ask(
      full_prompt,
      with: image_context
    )

    optimized = response.content["optimized_prompt"]

    if optimized.present?
      @layer.update(prompt: optimized)
    end
  rescue StandardError => e
    Rails.logger.error("SmartFixImprover Error: #{e.message}")
    raise # Re-raise to propagate to job level for proper retry/discard handling
  end
end
