require "rails_helper"

RSpec.describe "Project Creation Analysis", type: :request do
  let(:user) { User.create!(email: "test@example.com", password: "password", name: "Test User", privacy_policy: true, completed_survey: true, onboarding_stage: :completed) }

  before do
    login_as(user, scope: :user)
    OnboardingResponse.create!(user: user, completed: true)
  end

  it "enqueues SketchAnalysisJob when creating a new project with an image" do
    file = fixture_file_upload("spec/fixtures/files/test_image.png", "image/png")

    expect {
      post projects_path, params: { image: file }
    }.to have_enqueued_job(SketchAnalysisJob)

    expect(ProjectLayer.last.original?).to be true
    expect(ProjectLayer.last.image).to be_attached
  end
end
