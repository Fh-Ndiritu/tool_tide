# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentTransactionsController, type: :controller do
  fixtures(:users)
  let(:user) { users(:john_doe) }
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
        before do
          allow(Paystack::VerifyPayment).to receive(:perform).and_return(Dry::Monads::Success(true))
        end

        it "sets a success flash and redirects to credits_path" do
          get :callback, params: { reference: "123" }
          expect(flash[:success]).to eq("Payment successful!")
          expect(response).to redirect_to(credits_path)
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
