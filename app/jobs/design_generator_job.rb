class DesignGeneratorJob < ApplicationJob
  queue_as :generation

  def perform(id)
    mask_request = MaskRequest.find(id)
    user = mask_request.user
    cost = GOOGLE_PRO_IMAGE_COST * 3 # DesignGenerator creates 3 variants

    if !mask_request.mask.attached?
      mask_request.reload
    end

    return unless mask_request.mask.attached?

    # CRITICAL: Charge User logic
    user.with_lock do
      if user.pro_engine_credits < cost
        mask_request.update!(progress: :failed, user_error: "Insufficient credits to process design.")
        return
      end

      user.pro_engine_credits -= cost
      user.save!

      CreditSpending.create!(
        user: user,
        amount: cost,
        transaction_type: :spend,
        trackable: mask_request
      )
    end

    DesignGenerator.perform(mask_request)
  rescue StandardError => e
    # CRITICAL: Refund on failure
    user.with_lock do
      user.pro_engine_credits += cost
      user.save!
      CreditSpending.create!(
        user: user,
        amount: cost,
        transaction_type: :refund,
        trackable: mask_request
      )
    end

    mask_request.update!(progress: :failed, user_error: "An unexpected error occurred.")
    raise e
  end
end
