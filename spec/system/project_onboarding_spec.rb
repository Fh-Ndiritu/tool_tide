require "rails_helper"

RSpec.describe "Project Onboarding", type: :system do
  before do
    driven_by(:headless_chrome)
  end

  let(:user) { User.create!(email: "test@example.com", password: "password", name: "Test User", privacy_policy: true) }
  let(:project) { Project.create!(user: user, title: "Test Project") }
  let(:design) { Design.create!(project: project) }
  let(:root_layer) { design.project_layers.create!(layer_type: :original, status: :complete, project: project) }

  before do
    login_as(user, scope: :user)
    # Ensure there's an image attached to the root layer for the project view to render
    file = fixture_file_upload(Rails.root.join("spec/fixtures/files/test.png"), "image/png")
    root_layer.display_image.attach(file)
    design.update(current_project_layer_id: root_layer.id)
  end

  it "guides the user through the Style Presets tour" do
    visit project_path(project)

    # 1. Style Presets Tab
    expect(page).to have_content("Style Presets", wait: 10)
    expect(page).to have_content("transform your garden", wait: 10)

    # Click Next in popover (Driver.js)
    find(".driver-popover-next-btn").click

    # 2. Preset Grid
    expect(page).to have_content("Select a Preset", wait: 10)
    find(".driver-popover-next-btn").click

    # 3. Canvas Hint
    expect(page).to have_content("Paint the Canvas", wait: 10)
    find(".driver-popover-next-btn").click

    # 4. Variations
    expect(page).to have_content("Choose Variations", wait: 10)
    find(".driver-popover-next-btn").click

    # 5. Generate Button
    expect(page).to have_content("Generate Now", wait: 10)

    # Verify status update in DB
    user.reload
    expect(user.project_onboarding.style_presets_status).to eq("generate_seen")
  end
end
