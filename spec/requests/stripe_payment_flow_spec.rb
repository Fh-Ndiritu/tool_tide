require 'rails_helper'

RSpec.describe 'Stripe Payment Flow', type: :request do
  fixtures :users

  let(:user) { users(:one) }
  let(:stripe_session_id) { 'cs_test_123' }

  before do
    host! 'localhost'
    sign_in user
  end

  describe 'POST /payment_transactions' do
    it 'initiates checkout and redirects to stripe' do
      allow(Stripe::InitializeCheckout).to receive(:perform)
        .with(kind_of(PaymentTransaction), user)
        .and_return(Dry::Monads::Success('https://stripe.com/checkout'))

      post payment_transactions_path

      expect(response).to redirect_to('https://stripe.com/checkout')
      expect(PaymentTransaction.count).to eq(1)
    end

    it 'handles failure gracefully' do
      allow(Stripe::InitializeCheckout).to receive(:perform)
        .and_return(Dry::Monads::Failure('Something went wrong'))

      post payment_transactions_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include('An error occurred')
    end
  end

  describe 'GET /stripe/callback' do
    let!(:transaction) { PaymentTransaction.create!(user: user, amount: 10, uuid: SecureRandom.hex(16), currency: 'USD', stripe_session_id: stripe_session_id) }

    context 'when webhook has already processed the payment (Success)' do
      before do
        # Simulate webhook having run
        transaction.update!(status: :success, validated: true, credits_issued: true)
      end

      it 'shows success message and redirects to credits' do
        get stripe_callback_path(session_id: stripe_session_id)

        expect(response).to redirect_to(credits_path)
        expect(flash[:success]).to eq('Payment successful!')
      end
    end

    context 'when webhook has NOT arrived yet (Processing)' do
      before do
        # Transaction exists but is still pending
        transaction.update!(status: :pending)
      end

      it 'shows processing message and redirects to credits' do
        get stripe_callback_path(session_id: stripe_session_id)

        expect(response).to redirect_to(credits_path)
        expect(flash[:notice]).to include('processing')
      end
    end

    context 'when transaction is missing' do
      it 'shows failure message' do
        get stripe_callback_path(session_id: 'non_existent_id')

        expect(response).to redirect_to(credits_path)
        expect(flash[:alert]).to include('Transaction not found')
      end
    end
  end
end
