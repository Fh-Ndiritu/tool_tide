class AutoFixDetectorService
  class AutoFixListSchema < RubyLLM::Schema
    array :fixes, description: "A list of 6 distinct atomic improvements" do
      object do
        string :title, description: "Short title of the fix (e.g. 'Add Swimming Pool')"
        string :description, description: "Brief, scientifically accurate description including feature positional data (e.g. 'Install a rectangular pool between the red planter on bottom right and the Joshua tree on the top left')"
      end
    end
  end

  def initialize(project_layer)
    @layer = project_layer
  end

  def self.perform(project_layer)
    new(project_layer).detect
  end

  def detect
    # Pass display_image directly - RubyLLM handles ActiveStorage attachments
    image_context = @layer.display_image

    system_prompt = <<~PROMPT
      You are a professional Landscape Architect AI.
      Analyze the provided image and identify 6 distinct, atomic improvements.
      Each improvement must be a specific, actionable change (e.g., adding a feature, replacing a plant, removing an object).
      Each feature must make architectural and landscaping sense from an expert landscape architect's perspective.
      Include precise positional data in the description (e.g., "in the foreground", "top right corner").
      Ensure descriptions are scientifically accurate and concise.
    PROMPT


    response = CustomRubyLLM.context.chat.with_schema(AutoFixListSchema).ask(
      "Detect 6 atomic fixes for this landscape. #{system_prompt}",
      with: image_context
    )

    fixes = response.content["fixes"]

    ActiveRecord::Base.transaction do
      fixes.each do |fix_data|
        @layer.auto_fixes.create!(
          title: fix_data["title"],
          description: fix_data["description"],
          status: :pending
        )
      end
    end

    @layer.auto_fixes.reload
  rescue StandardError => e
    Rails.logger.error("AutoFixDetectorService Error: #{e.message}")
    [] # Return empty array on failure
  end
end
