# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentTransactionsController, type: :controller do
  let(:user) { instance_double(User) }
  let(:transaction) { instance_double(PaymentTransaction, uuid: 'TRANS-UUID', amount: 100.0, save!: true, update!: true, issue_credits: true) }

  before do
    allow(request.env['warden']).to receive(:authenticate!).and_return(user)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe 'POST #create' do
    let(:order_result) { double('Order', id: 'ORDER-123', status: 'CREATED') }

    before do
      allow(PaymentTransaction).to receive(:new_transaction).with(user).and_return(transaction)
      allow(Paypal::CreateOrder).to receive(:perform).with(transaction).and_return(Dry::Monads::Success(order_result))
    end

    it 'creates a PayPal order and returns JSON' do
      post :create, format: :json
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['id']).to eq('ORDER-123')
      expect(json_response['status']).to eq('CREATED')
    end

    context 'when order creation fails' do
      before do
        allow(Paypal::CreateOrder).to receive(:perform).and_return(Dry::Monads::Failure('Error message'))
      end

      it 'returns unprocessable entity' do
        post :create, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to eq('Error message')
      end
    end
  end

  describe 'POST #capture' do
    let(:capture_data) do
      double('CaptureData',
        id: 'ORDER-123',
        status: 'COMPLETED',
        payer: double('Payer', payer_id: 'PAYER-123'),
        purchase_units: [ double('PurchaseUnit', reference_id: 'TRANS-UUID') ],
        to_hash: {
          'id' => 'ORDER-123',
          'status' => 'COMPLETED',
          'purchase_units' => [
            {
              'reference_id' => 'TRANS-UUID',
              'payments' => {
                'captures' => [
                  {
                    'id' => 'CAPTURE-123',
                    'status' => 'COMPLETED'
                  }
                ]
              }
            }
          ]
        }
      )
    end

    before do
      allow(Paypal::CaptureOrder).to receive(:perform).with('ORDER-123').and_return(Dry::Monads::Success(capture_data))
      allow(PaymentTransaction).to receive(:find_by).with(uuid: 'TRANS-UUID').and_return(transaction)
    end

    it 'captures the order and updates transaction' do
      expect(transaction).to receive(:update!).with(
        paypal_order_id: 'ORDER-123',
        paypal_payer_id: 'PAYER-123',
        status: :success,
        paid_at: anything,
        method: 'paypal',
        validated: true
      )
      expect(transaction).to receive(:issue_credits)

      post :capture, params: { order_id: 'ORDER-123' }, format: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['id']).to eq('ORDER-123')
    end

    it 'triggers email notification when credits are issued' do
      # Allow the actual issue_credits to be called
      allow(transaction).to receive(:issue_credits).and_call_original
      allow(transaction).to receive(:user).and_return(user)
      allow(user).to receive(:credits).and_return(double(create!: true))

      expect {
        post :capture, params: { order_id: 'ORDER-123' }, format: :json
      }.to have_enqueued_mail(UserMailer, :credits_purchased_email)
    end

    context 'when capture fails' do
      before do
        allow(Paypal::CaptureOrder).to receive(:perform).and_return(Dry::Monads::Failure('Capture failed'))
      end

      it 'returns unprocessable entity' do
        post :capture, params: { order_id: 'ORDER-123' }, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
