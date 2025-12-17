class SketchPipelineService
  CREDIT_COST = 3 * GOOGLE_IMAGE_COST

  def initialize(canva)
    @canva = canva
  end

  def self.analyze_image(canva)
    # This logic belongs to SketchAnalysisJob
  end

  def start_generation
    return unless check_credits

    sketch_request = @canva.sketch_requests.create!(
      progress: :processing_architectural,
      user: @canva.user
    )

    # Deduct credits
    @canva.user.charge_pro_cost!(CREDIT_COST)
    @canva.update!(treat_as: :sketch)

    # Trigger Generation
    SketchGenerationJob.perform_later(sketch_request)

    sketch_request
  rescue => e
    Rails.logger.error("Failed to start sketch generation: #{e.message}")
    nil
  end

  def self.refund_on_failure(sketch_request)
    user = sketch_request.canva.user
    user.increment!(:pro_engine_credits, CREDIT_COST)
  end

  private

  def check_credits
    if @canva.user.pro_engine_credits < CREDIT_COST
      false
    else
      true
    end
  end
end
