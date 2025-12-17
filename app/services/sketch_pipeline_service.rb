class SketchPipelineService
  CREDIT_COST = 3 * GOOGLE_IMAGE_COST

  def initialize(canva)
    @canva = canva
  end

  def self.analyze_image(canva)
    # This logic belongs to SketchAnalysisJob
  end

  def start_generation
    return unless @canva.user.afford_generation?

    sketch_request = @canva.sketch_requests.create!(
      progress: :processing_architectural,
      user: @canva.user
    )

    @canva.update!(treat_as: :sketch)

    # Trigger Generation
    SketchGenerationJob.perform_later(sketch_request)

    sketch_request
  rescue => e
    Rails.logger.error("Failed to start sketch generation: #{e.message}")
    nil
  end

  private
end
