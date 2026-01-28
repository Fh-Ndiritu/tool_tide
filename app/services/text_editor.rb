class TextEditor
  include Designable

  def initialize(id)
    @text_request = TextRequest.find(id)
  end

  def self.perform(*args)
    new(*args).generate
  end

  def generate
    user = @text_request.user
    cost = GOOGLE_PRO_IMAGE_COST

    # CRITICAL: Charge before generation
    charged = false
    user.with_lock do
      if user.pro_engine_credits >= cost
        user.pro_engine_credits -= cost
        user.save!
        CreditSpending.create!(
          user: user,
          amount: cost,
          transaction_type: :spend,
          trackable: @text_request
        )
        charged = true
      end
    end

    unless charged
      @text_request.update!(progress: :failed, error_msg: "Insufficient credits", user_error: "Insufficient credits")
      return
    end

    @text_request.update user_error: nil, error_msg: nil, progress: :preparing

    process_with_text

    @text_request.processed!
    @text_request.user.refinement_generated!
    @text_request.complete!

  rescue StandardError => e
    # CRITICAL: Refund on failure
    user.with_lock do
      user.pro_engine_credits += cost
      user.save!
      CreditSpending.create!(
        user: user,
        amount: cost,
        transaction_type: :refund,
        trackable: @text_request
      )
    end

    if e.is_a?(Faraday::ServerError)
       user_error = "We are having some downtime, try again later ..."
       @text_request.update error_msg: e.message, progress: :failed, user_error: user_error
    else
       raise e
    end
  end

  private

  def process_with_text
    # TextRequestQualifier.perform(@text_request)
    image = @text_request.original_image
    payload = gcp_payload(prompt: @text_request.prompt, image:)
    @text_request.generating!
    response = fetch_gcp_response(payload)
    blob = save_gcp_results(response)
    @text_request.result_image.attach(blob)
    @text_request.save
  end

  def prompt
    "Role:
    You are very creative landscaping expert who takes a home-owner's requests and translates them into professional-grade landscape/garden changes.
    Your task is to understand a vague home-owner request they want to make on a photo of their garden analyze it and provide a list
    of professional landscaping and garden changes that a creative landscaper would make to fulfil the request.

   <system_prompt>
     FOLLOW these steps to provide a list of changes needed to the image:
      - THE GARDEN LANDSCAPE MUST always be stunning, professional, photorealistic, and display a vibrant design that is creative and practical.
      - ANY features, plants, materials or elements you use MUST be vibrant, chic and beatiful to achieve a professional aesthetic.
      - Analyze the photo of the house and the garden/landscape around it to understand the size of the area you are working with.
      - Analyze the home-owner's request and list things that a creative landscaper needs to change to perfectly fulfil this request, if the homeowner is made a very specific request, you don't need to provide any other changes.
      - If the prompt is quite vague, or very broad, that's when you need to provide a list of changes needed to realize their request.
      - The goal is to ensure we achieve everything they want and keep the rest of the photo the same.
      - You shall provide the recommended changes as list of recommended edits to the image.
      - Each list items needs to be very clear what is being done, what moved, where, replaced what, with what, what color, what plant??
      - Carefully analze these changes to ensure the landscaper meets the expectations of the home-owner without modifying things unnecessarily.
      - Finally convert the list into a prose and detailed instruction to the landscaper using this response guide:

    TAKE YOUR TIME TO carefully go through these steps and instructions before providing a response.
    <response_guide>
      CAREFULLY review your modifications to ensure you have understood, fulfilled and not changed things the home-owner did not ask for.
      Enhance Materiality & Texture: Convert vague requests into specific textures
        - Instead of 'nice path,' use 'a flagstone path with mossy joints and a matte finish.'
        - Instead of 'plants,' use 'lush, waxy tropical foliage' or 'ornamental grasses with soft, feathery textures.'
      Write in full, descriptive sentences that are rich and informative and easy to grasp what they change
    </response_guide>

    TAKE YOUR TIME TO carefully go through these steps and instructions before providing a response.

    Finally, modify the image to implement these changes
   </system_prompt>

  <user_or_home_owner_request/>
    #{ @text_request.prompt }
  </user_or_home_owner_request>
    "
  end
end
