class BackfillTrialGenerationJob < ApplicationJob
  queue_as :default

  def perform
    MaskRequest.complete.where(trial_generation: false).find_each do |mask_request|
      unless mask_request.user.has_paid?
        mask_request.update_column(:trial_generation, true)
      end
    end

    TextRequest.complete.where(trial_generation: false).find_each do |text_request|
      unless text_request.user.has_paid?
        text_request.update_column(:trial_generation, true)
      end
    end
  end
end
