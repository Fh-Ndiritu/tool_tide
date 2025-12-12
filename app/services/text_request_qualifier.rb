class RefinedPromptSchema < RubyLLM::Schema
  object :response do
    string :recommended_changes, description: "The list of recommended changes to realize the user's request."
  end
end

class TextRequestQualifier
  def initialize(text_request)
    @text_request = text_request
  end

  def self.perform(text_request)
    new(text_request).perform
  end

  def perform
    # return if @text_request.recommended_changes.present?
    @text_request.analyzing!
    prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("prompt_qualification")

    # Replace variables if needed, though the prompt seems to be a system instruction.
    # The user prompt is passed as context or part of the message.
    # RubyLLM.chat.ask(prompt, with: image) seems to be the pattern.
    # But we need to pass the user's request too.

    full_prompt = "#{prompt}\n\nUser Request: #{@text_request.prompt}\n\nIMPORTANT: Provide ONLY the list of recommended changes in the JSON response. DO NOT generate any images."

    response = RubyLLM.chat.with_schema(RefinedPromptSchema).ask(
      full_prompt,
      with: @text_request.original_image
    )

    recommended_changes = response.content["response"]["recommended_changes"]

    @text_request.update!(refined_prompt: recommended_changes)
  end
end
