require 'rails_helper'

RSpec.describe 'Stripe Checkout Flow', type: :system do
  before do
    driven_by(:rack_test)
    Rails.application.routes.default_url_options[:host] = 'localhost'
    Capybara.app_host = 'http://localhost'
  end

  it 'allows user to buy credits via Stripe' do
    # Create a fresh user who has NOT paid (to see the welcome/paywall page)
    user = User.create!(
      email: "checkout_test@example.com",
      password: "password",
      name: "Checkout User",
      privacy_policy: true,
      has_paid: false,
      onboarding_stage: :completed
    )
    OnboardingResponse.create!(user: user, completed: true)

    sign_in user
    visit welcome_path

    expect(page).to have_content('Starter Pack')
    expect(page).to have_content('$10')

    allow(Stripe::InitializeCheckout).to receive(:perform) do |transaction, _user|
      callback_url = Rails.application.routes.url_helpers.stripe_callback_path(session_id: 'cs_fake_123')

      # Simulate creation of transaction details that Stripe would return
      transaction.update!(stripe_session_id: 'cs_fake_123')

      Dry::Monads::Success(callback_url)
    end

    # We no longer mock VerifyPayment because the controller doesn't call it.
    # Instead, we must simulate the webhook updating the DB *before* the user lands on the callback page
    # OR we rely on the controller handling the "processing" state.

    # To test the "success" path, we can cheat and update the DB right before the controller check happens?
    # In a system spec driven by rack_test, requests are synchronous.
    # So when we click "Proceed", it goes to controller -> redirects to callback_url.
    # The callback_url access happens immediately.

    # Let's hook into the redirect? Or just update it?
    # Actually, InitializeCheckout returns the URL. `click_button` follows it?
    # If the URL is internal (stripe_callback_path), RackTest follows it immediately.

    # We need to ensure the transaction is marked success BEFORE the callback is hit.
    allow(Stripe::InitializeCheckout).to receive(:perform) do |transaction, _user|
      transaction.update!(stripe_session_id: 'cs_fake_123')

      # Simulate webhook side-effect immediately
      transaction.update(status: :success, validated: true)
      transaction.issue_credits

      callback_url = Rails.application.routes.url_helpers.stripe_callback_path(session_id: 'cs_fake_123')
      Dry::Monads::Success(callback_url)
    end

    click_button 'Proceed to Secure Checkout'

    expect(page).to have_current_path(credits_path)
    expect(page).to have_content('Payment successful!')
    expect(user.reload.pro_engine_credits).to be > 0
  end
end
