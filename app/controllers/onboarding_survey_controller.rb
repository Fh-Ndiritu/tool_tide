class OnboardingSurveyController < ApplicationController
  before_action :set_survey

  def show
    redirect_to new_project_path if current_user.can_skip_onboarding_survey?
  end

  def update
    if @survey.update(survey_params)
      if survey_complete?
        @survey.complete!
        redirect_to new_project_path
      else
        redirect_to onboarding_survey_path
      end
    end
  end

  private

  def set_survey
    @survey = current_user.onboarding_response || current_user.create_onboarding_response
  end

  def survey_params
    params.require(:onboarding_response).permit(:role, :intent, :pain_point)
  end

  def survey_complete?
    @survey.role.present? && @survey.intent.present? && @survey.pain_point.present?
  end
end


# roles = {}
# intent = {}
# pain_points = {}
# OnboardingResponse.all.each do |response|
#   roles[response.role] = (roles[response.role] || 0) + 1
#   intent[response.intent] = (intent[response.intent] || 0) + 1
#   pain_points[response.pain_point] = (pain_points[response.pain_point] || 0) + 1
# end
