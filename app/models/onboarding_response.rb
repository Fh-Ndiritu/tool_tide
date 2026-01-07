class OnboardingResponse < ApplicationRecord
  belongs_to :user

  enum :role, {
    homeowner: 0,
    professional: 1,
    agent: 2
  }

  enum :intent, {
    inspiration: 0,
    renovation: 1,
    client_pres: 2,
    approval: 3
  }

  enum :pain_point, {
    visualization: 0,
    knowledge: 1,
    sketch_quality: 2
  }

  def complete!
    transaction do
      update!(completed: true, completed_at: Time.current)
      user.update(completed_survey: true)
      user.issue_signup_credits
    end

  end
end
