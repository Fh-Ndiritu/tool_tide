class BackfillTrialGenerationJob < ApplicationJob
  queue_as :default

  def perform
    MaskRequest.complete.where(trial_generation: false).find_each do |mask_request|
      unless mask_request.user.has_purchased_credits_before?(mask_request.created_at)
        mask_request.update_column(:trial_generation, true)
      end
    end

    TextRequest.complete.where(trial_generation: false).find_each do |text_request|
      unless text_request.user.has_purchased_credits_before?(text_request.created_at)
        text_request.update_column(:trial_generation, true)
      end
    end
  end
end
