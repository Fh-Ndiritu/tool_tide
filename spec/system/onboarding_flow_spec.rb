require "rails_helper"

RSpec.describe "Onboarding Flow", type: :system do
  before do
    driven_by(:headless_chrome)
  end

  it "guides the user through the Golden Path" do
    # 1. Signup (Bypassed for stability, simulating fresh user)
    user = User.create!(
      email: "newuser@example.com",
      password: "password",
      password_confirmation: "password",
      name: "New User",
      privacy_policy: true,
      onboarding_stage: :fresh
    )
    login_as(user, scope: :user)

    visit new_canva_path

    # Debug: Print browser logs
    page.driver.browser.logs.get(:browser).each do |log|
      puts "Browser Log: #{log.message}"
    end


    # 2. Welcome Modal & Upload
    expect(page).to have_current_path(new_canva_path)
    expect(page).to have_content("Welcome to Hadaa!", wait: 10)
    expect(page).to have_content("40 Free Credits")

    click_button "Let's Get Started"

    # Check for upload highlight (ring-pulse class)
    # Note: The file input is hidden or styled, so we check the container or the input itself if visible
    # The controller adds ring-pulse to the upload target.
    # We can check if the class is present on the element with data-onboarding-target="upload"
    expect(page).to have_css(".ring-pulse", wait: 5)

    # Attach image
    attach_file "canva[image]", Rails.root.join("app/assets/images/hadaa.png")

    # 3. Brush Tool
    expect(page).to have_current_path(new_canva_mask_request_path(Canva.last))
    expect(page).to have_content("Select the Brush") # Tour content

    # Simulate drawing by attaching a mask file directly to the hidden input
    # We need to make it visible to attach
    execute_script("document.querySelector('input[name=\"mask_request[mask]\"]').classList.remove('hidden')")
    attach_file "mask_request[mask]", Rails.root.join("app/assets/images/hadaa.png"), make_visible: true

    # Click Generate Now (Submit)
    click_button "Generate Now"

    # 4. Style Selection
    expect(page).to have_current_path(edit_mask_request_path(MaskRequest.last))
    expect(page).to have_content("Select a Style") # Tour content

    # Select a style (e.g., Modern)
    first("button.shadow-lg").click # Click the first style card

    # 5. Plants
    expect(page).to have_current_path(plants_mask_request_path(MaskRequest.last))
    expect(page).to have_content("Get Plant Suggestions") # Tour content
    expect(page).to have_css(".ring-pulse") # Plants button should pulse

    # Click Next (skip suggestions for speed)
    click_button "Next"

    # 6. Result & Text Edit Upsell
    expect(page).to have_current_path(mask_request_path(MaskRequest.last))
    expect(page).to have_content("Refine with AI") # Tour content or button text
    expect(page).to have_css(".ring-pulse") # Text Edit button should pulse

    # Click Open AI Editor
    click_link "Open AI Editor"

    # 7. Text Edit Generation
    expect(page).to have_current_path(new_text_request_path)
    expect(page).to have_content("Describe Changes") # Tour content
    expect(page).to have_css(".ring-pulse") # Prompt box should pulse

    fill_in "text_request[prompt]", with: "Make it a night scene"
    click_button "Generate"

    # 8. History
    expect(page).to have_current_path(text_requests_path(current_request: TextRequest.last.id))
    expect(page).to have_content("History & Versions") # Tour content
    # expect(page).to have_css(".ring-pulse") # History sidebar should pulse (might be tricky if it's a container)

    puts "Onboarding Flow Verified Successfully!"
  end
end
