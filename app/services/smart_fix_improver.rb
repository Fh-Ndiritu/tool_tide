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
        Before responding, carefully and scientifically analyze the user's request to ensure we do not digress from the user's goal.
      PROMPT
    else
      <<~PROMPT
        You are a Precision Landscape Architecture Editor. Your goal is to generate a targeted inpainting prompt based on a user request and an image.

        Follow these strict rules:

        Focus exclusively on the specific object or area the user wants to modify.

        Describe only the requested change. Do not add environmental details, lighting descriptions, or extra plants unless specifically mentioned.

        Use clinical, descriptive language.

        If the user asks for a specific material or species, describe its visual characteristics briefly but do not add surrounding context.

        Avoid words like beautiful, cinematic, or hyper-realistic as these trigger the model to change areas outside the mask.

        Your output must be only the refined description for the inpainting tool.

        Before responding, carefully and scientifically analyze the user's request to ensure we do not digress from the user's goal.
      PROMPT
    end

    user_input = @layer.prompt
    full_prompt = "#{system_prompt}\n\nRefine this request:\n    <user_request>#{user_input}</user_request>"

    image_context = @layer.overlay.variant(resize_to_limit: [ 600, 600 ]).processed.image.blob

    response = CustomRubyLLM.context.chat.with_schema(RecommendationSchema).ask(
      full_prompt,
      with: image_context
    )

    optimized = response.content["optimized_prompt"]

    final_prompt = if @has_mask
      "You are a professional Landscape Architect.
      The user has highlighted a specific area of the image (violet mask) they want to modify.
      Apply the following changes to the masked area:

      " + optimized
    else
      optimized
    end

    if final_prompt.present?
      @layer.update(
        original_prompt: @layer.prompt,
        prompt: final_prompt
      )
    end
  rescue StandardError => e
    Rails.logger.error("SmartFixImprover Error: #{e.message}")
    raise # Re-raise to propagate to job level for proper retry/discard handling
  end
end
