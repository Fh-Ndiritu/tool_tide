class OnboardingResponse < ApplicationRecord
  belongs_to :user

  enum :role, {
    professional: 1,
    homeowner: 0,
    agent: 2
  }

  enum :intent, {
    client_pres: 2,
    inspiration: 0,
    renovation: 1,
    approval: 3
  }

  enum :pain_point, {
    knowledge: 1,
    visualization: 0,
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
