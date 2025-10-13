class TextEditor
  include Designable

  def initialize(id)
    @text_request = TextRequest.find(id)
  end

  def self.perform(*args)
    new(*args).generate
  end

  def generate
    @text_request.update user_error: nil, error_msg: nil, progress: :preparing

    process_with_text

    @text_request.processed!
    charge_generation

  rescue Faraday::ServerError => e
    user_error = e.is_a?(Faraday::ServerError) ? "We are having some downtime, try again later ..." : "Something went wrong, try a different style."
    @text_request.update error_msg: e.message, progress: :failed, user_error:
  end

  private

  def process_with_text
    prompt = @text_request.prompt
    image = @text_request.original_image
    payload = gcp_payload(prompt:, image:)
    @text_request.generating!
    response = fetch_gcp_response(payload)
    blob = save_gcp_results(response)
    @text_request.result_image.attach(blob)
    @text_request.save
  end

  def charge_generation
    if @text_request.reload.result_image.attached?
      cost = GOOGLE_IMAGE_COST * 1
      trial_generation = @text_request.user.pro_trial_credits >= cost

      @text_request.user.charge_pro_cost!(cost)
      @text_request.update!(progress: :complete, trial_generation:)
    else
      @text_request.update!(progress: :failed, error_msg: "Result not found")
    end
  end
end
