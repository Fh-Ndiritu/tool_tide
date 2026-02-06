require 'rails_helper'

RSpec.describe Stripe::InitializeCheckout do
  fixtures :users

  let(:user) { users(:one) }
  let(:transaction) { PaymentTransaction.create!(user: user, amount: 10, uuid: SecureRandom.hex(16), currency: 'usd') }
  let(:stripe_customer_id) { 'cus_test123' }
  let(:stripe_session_id) { 'cs_test_session_123' }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('STRIPE_PRICE_ID').and_return('price_test123')
    allow(ENV).to receive(:fetch).with('APP_HOST', 'localhost:3000').and_return('localhost:3000')
  end

  describe '.perform' do
    context 'when user already has a stripe_customer_id' do
      before do
        user.update!(stripe_customer_id: stripe_customer_id)
      end

      it 'uses existing customer and creates checkout session' do
        expect(Stripe::Customer).not_to receive(:create)
        expect(Stripe::Customer).not_to receive(:search)

        expect(Stripe::Checkout::Session).to receive(:create).with(
          hash_including(
            customer: stripe_customer_id,
            line_items: [ { price: 'price_test123', quantity: 1 } ],
            mode: 'payment'
          )
        ).and_return(double(id: stripe_session_id, url: 'https://checkout.stripe.com/pay/cs_test'))

        result = described_class.perform(transaction, user)

        expect(result).to be_success
        expect(result.value!).to eq('https://checkout.stripe.com/pay/cs_test')
        expect(transaction.reload.stripe_session_id).to eq(stripe_session_id)
        expect(transaction.status).to eq('pending')
      end
    end

    context 'when user does not have stripe_customer_id but exists in Stripe' do
      it 'searches for customer, updates user, and creates session' do
        search_result = double(data: [ double(id: stripe_customer_id) ])
        allow(Stripe::Customer).to receive(:search).with(query: "email:'#{user.email}'").and_return(search_result)
        expect(Stripe::Customer).not_to receive(:create)

        expect(Stripe::Checkout::Session).to receive(:create).and_return(double(id: stripe_session_id, url: 'https://example.com'))

        result = described_class.perform(transaction, user)

        expect(result).to be_success
        expect(user.reload.stripe_customer_id).to eq(stripe_customer_id)
      end
    end

    context 'when user is new to Stripe' do
      it 'creates a new customer and session' do
        allow(Stripe::Customer).to receive(:search).and_return(double(data: []))
        expect(Stripe::Customer).to receive(:create).with(
          hash_including(email: user.email, metadata: { user_id: user.id })
        ).and_return(double(id: stripe_customer_id))

        expect(Stripe::Checkout::Session).to receive(:create).and_return(double(id: stripe_session_id, url: 'https://example.com'))

        result = described_class.perform(transaction, user)

        expect(result).to be_success
        expect(user.reload.stripe_customer_id).to eq(stripe_customer_id)
      end
    end

    context 'when Stripe API fails' do
      it 'returns a Failure monad' do
        allow(Stripe::Customer).to receive(:search).and_raise(Stripe::StripeError.new('API Error'))

        result = described_class.perform(transaction, user)

        expect(result).to be_failure
        expect(result.failure).to include('Stripe Customer Creation failed: API Error')
      end
    end
  end
end
