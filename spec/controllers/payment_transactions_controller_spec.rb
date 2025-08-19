require 'rails_helper'

RSpec.describe PaymentTransactionsController, type: :controller do

  fixtures :users

  before(:each) do
    sign_in User.last, scope: :user
  end

  context 'when initializing a new payment' do
    describe 'creates the default record ' do
      it 'returns a valid reference_id', focus: do
        post '/payment_transactions'
        # expect(response).to have_http_status(:ok)
        # expect(user.payment_transactions.count).to eq(1)
        # expect(user.payment_transactions.last.reference_id).to be_present
        # expect(user.payment_transactions.last.amount).to be > 0
      end
    end
  end

end
