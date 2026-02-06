require 'rails_helper'

RSpec.describe Stripe::VerifyPayment do
  fixtures :users

  let(:user) { users(:two) }
  let(:transaction) { PaymentTransaction.create!(user: user, amount: 10, uuid: SecureRandom.hex(16), currency: 'USD', status: :pending) }
  let(:session_id) { 'cs_test_123' }

  # Mock Stripe::Event
  let(:stripe_event_data) do
    double(
      object: double(
        id: session_id,
        customer: 'cus_test_123',
        client_reference_id: transaction.id.to_s,
        payment_status: 'paid'
      )
    )
  end

  let(:stripe_event) do
    double(
      data: stripe_event_data
    )
  end

  describe '.perform' do
    context 'when payment is successful' do
      it 'issues credits and marks transaction as success' do
        result = described_class.perform(stripe_event)

        expect(result).to be_success
        updated_transaction = result.value!
        expect(updated_transaction.status).to eq('success')
        expect(updated_transaction.validated).to be true
        expect(updated_transaction.credits_issued).to be true
        expect(user.reload.credits.count).to eq(1)
        expect(user.has_paid).to be true
      end
    end

    context 'when payment is not paid' do
      let(:stripe_event_data) do
        double(
          object: double(
            id: session_id,
            customer: 'cus_test_123',
            client_reference_id: transaction.id.to_s,
            payment_status: 'unpaid'
          )
        )
      end

      it 'returns failure' do
        result = described_class.perform(stripe_event)
        expect(result).to be_failure
        expect(result.failure).to include('Payment not paid')
        expect(transaction.reload.status).to eq('pending')
      end
    end

    context 'when transaction is not found' do
      let(:stripe_event_data) do
        double(
          object: double(
            id: session_id,
            customer: 'cus_test_123',
            client_reference_id: 'non_existent_id',
            payment_status: 'paid'
          )
        )
      end

      it 'returns failure' do
        result = described_class.perform(stripe_event)
        expect(result).to be_failure
        expect(result.failure).to include('PaymentTransaction not found')
      end
    end

    context 'when credits update fails' do
       before do
         # We need to stub the instance that is found by the service
         allow(PaymentTransaction).to receive(:find_by).and_return(transaction)
         allow(transaction).to receive(:update).with(status: :success, validated: true).and_return(false)
         allow(transaction).to receive(:errors).and_return(double(full_messages: [ "Update failed" ]))
       end

       it 'returns failure' do
         result = described_class.perform(stripe_event)
         expect(result).to be_failure
         expect(result.failure).to include('Failed to update transaction')
       end
    end
  end
end
