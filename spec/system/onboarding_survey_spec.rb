require "rails_helper"

RSpec.describe "Onboarding Survey", type: :system do
  before do
    driven_by(:headless_chrome)
    Capybara.app_host = "http://localhost"
  end

  it "forces the user to complete the survey and issues credits" do
    user = User.create!(
      email: "survey@example.com",
      password: "password",
      password_confirmation: "password",
      name: "Survey User",
      privacy_policy: true
    )
    user.credits.destroy_all

    login_as(user, scope: :user)
    visit mask_requests_path

    # Should be redirected to survey
    puts "Current path: #{page.current_path}"
    expect(page).to have_current_path(onboarding_survey_path)
    expect(page).to have_content("To load the right tools for you")
    expect(user.credits.where(source: :signup).count).to eq(0)

    # Step 1: Role
    find("h3", text: "Homeowner").click

    # Step 2: Intent
    expect(page).to have_content("What is the main result", wait: 5)
    find("h3", text: "Inspiration").click

    # Step 3: Problem
    expect(page).to have_content("What is the hardest part", wait: 5)
    find("h3", text: "\"I can't visualize it\"").click

    # Celebration
    expect(page).to have_content("Welcome to Hadaa!", wait: 10)
    expect(page).to have_content("#{TRIAL_CREDITS} Free Credits")

    # Verify credits issued
    expect(user.reload.credits.where(source: :signup).sum(:amount)).to eq(TRIAL_CREDITS)

    # Redirect to workspace
    expect(page).to have_content("Let's Get Started")
    click_link "Let's Get Started"
    expect(page).to have_current_path(new_canva_path)
  end
end
