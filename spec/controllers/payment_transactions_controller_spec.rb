# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentTransactionsController, type: :controller do
  fixtures(:users)
  let(:user) { users(:one) }
  let(:transaction) { double("PaymentTransaction", authorization_url: "https://paystack.com/authorize") }

  before do
    sign_in(user)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe "POST #create" do
    context "when Paystack initialization is successful" do
      before do
        allow(PaymentTransaction).to receive(:new_transaction).and_return(transaction)
        allow(Paystack::InitializeCheckout).to receive(:perform).and_return(Dry::Monads::Success(transaction))
      end

      it "redirects to the Paystack authorization URL" do
        post :create
        expect(response).to redirect_to("https://paystack.com/authorize")
      end
    end

    context "when Paystack initialization fails" do
      before do
        allow(PaymentTransaction).to receive(:new_transaction).and_return(transaction)
        allow(Paystack::InitializeCheckout).to receive(:perform).and_return(Dry::Monads::Failure("Error"))
      end

      it "sets a flash alert and redirects to root" do
        post :create
        expect(flash[:alert]).to eq("An error occured, please try again later")
        expect(response).to redirect_to(root_path)
      end
    end

    context "when authorization_url is nil" do
      before do
        allow(PaymentTransaction).to receive(:new_transaction).and_return(transaction)
        allow(Paystack::InitializeCheckout).to receive(:perform).and_return(Dry::Monads::Success(PaymentTransaction.new))
      end

      it "sets a flash alert and redirects to root" do
        post :create
        expect(flash[:alert]).to eq("An error occured, please try again later")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET #callback" do
    context "when reference is present" do
      context "and payment verification is successful" do
        let(:payment_transaction) do
          PaymentTransaction.create!(
            user: user,
            amount: 10,
            currency: "usd",
            paystack_reference_id: "test_ref_123",
            credits_issued: false
          )
        end

        before do
          allow(Paystack::VerifyPayment).to receive(:perform).and_return(Dry::Monads::Success(true))
          allow(PaymentTransaction).to receive(:find_by).with(paystack_reference_id: "test_ref_123").and_return(payment_transaction)
        end

        it "sets a success flash and redirects to credits_path" do
          get :callback, params: { reference: "test_ref_123" }
          expect(flash[:success]).to eq("Payment successful!")
          expect(response).to redirect_to(credits_path)
        end

        it "sets conversion_event flash with transaction details" do
          get :callback, params: { reference: "test_ref_123" }
          expect(flash[:conversion_event]).to be_present
          expect(flash[:conversion_event][:transaction_id]).to eq("test_ref_123")
          expect(flash[:conversion_event][:value]).to eq(10.0)
          expect(flash[:conversion_event][:currency]).to eq("USD")
          expect(flash[:conversion_event][:credits]).to eq(200) # 10 * PRO_CREDITS_PER_USD (20)
        end

        it "does not set credits in conversion_event if already issued" do
          payment_transaction.update(credits_issued: true)
          get :callback, params: { reference: "test_ref_123" }
          expect(flash[:conversion_event][:credits]).to eq(0)
        end
      end

      context "and payment verification fails" do
        before do
          allow(Paystack::VerifyPayment).to receive(:perform).and_return(Dry::Monads::Failure("Error"))
        end

        it "sets an alert flash and redirects to credits_path" do
          get :callback, params: { reference: "123" }
          expect(flash[:alert]).to eq("Payment Failed, please try again later")
          expect(response).to redirect_to(credits_path)
        end
      end
    end

    context "when reference is missing" do
      it "sets an alert flash and redirects to root" do
        get :callback
        expect(flash[:alert]).to eq("No reference Id found")
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
