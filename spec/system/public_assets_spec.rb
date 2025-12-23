require 'rails_helper'

RSpec.describe "Public Assets", type: :system do
  let(:admin) { User.create!(email: "admin@example.com", password: "password", admin: true, privacy_policy: true) }
  let(:user) { User.create!(email: "user@example.com", password: "password", admin: false, privacy_policy: true) }

  before do
    driven_by(:rack_test)
  end

  it "allows admin to upload and view public assets" do
    sign_in admin
    visit admin_public_assets_path

    expect(page).to have_content("Public Assets")
    expect(page).to have_content("Upload New Asset")

    # Upload file
    attach_file "public_asset[image]", Rails.root.join("test/fixtures/files/image.jpg")
    fill_in "public_asset[name]", with: "Test Image"
    click_button "Upload"

    expect(page).to have_content("Public asset uploaded successfully")
    expect(page).to have_content("Test Image")

    asset = PublicAsset.last
    expect(asset.name).to eq("Test Image")
    expect(asset.uuid).to be_present

    # Verify public access
    sign_out admin
    visit public_asset_path(asset.uuid)

    expect(page).to have_css("img")
    expect(page).to have_content("Test Image")
    expect(page).to have_content("Powered by Hadaa AI Landscaper")
  end

  it "denies non-admin access to admin panel" do
    sign_in user
    visit admin_public_assets_path
    expect(page).to have_current_path(root_path)
  end
end
