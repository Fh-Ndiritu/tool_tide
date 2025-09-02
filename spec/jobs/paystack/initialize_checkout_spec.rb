# frozen_string_literal: true

# spec/paystack/initialize_checkout_spec.rb

require "rails_helper"
require "dry/monads"
require "faraday"

RSpec.describe Paystack::InitializeCheckout do
  include Dry::Monads[:result]
  # fixtures(:payment_transactions)
  fixtures(:users)

  subject { described_class.new(transaction) }

  let(:current_user) { users(:john_doe) }
  let(:transaction) { PaymentTransaction.new_transaction(current_user) }
  let(:valid_response) { { status: true, data: { access_code: "ACC_123", authorization_url: "https://paystack.com/authorize", reference: transaction.uuid } } }
  let(:invalid_response) { { status: false, data: {} } }
  let(:client) { double("Faraday") }
  let(:response) { double("Faraday::Response", body: valid_response.to_json, status: 200) }

  before do
    allow(Faraday).to receive(:new).and_return(client)
    allow(client).to receive(:post).and_return(response)
  end

  describe "#verify_transaction" do
    context "when transaction is valid" do
      it "returns Success" do
        expect(subject.send(:verify_transaction)).to eq(Success(true))
      end
    end

    context "when transaction already has an access_code" do
      before { allow(transaction).to receive(:access_code).and_return("ACC_123") }

      it "returns Failure" do
        expect(subject.send(:verify_transaction)).to eq(Failure("Transaction already has an access code"))
      end
    end

    context "when amount or uuid is missing" do
      before { allow(transaction).to receive(:amount).and_return(nil) }

      it "returns Failure" do
        expect(subject.send(:verify_transaction)).to eq(Failure("Amount or reference id is missing"))
      end
    end
  end

  describe "#fetch_checkout_code" do
    context "when API call is successful" do
      it "returns Success with parsed content" do
        expect(subject.send(:fetch_checkout_code)).to eq(Success(valid_response))
      end
    end

    context "when Faraday raises an error" do
      before { allow(client).to receive(:post).and_raise(Faraday::Error.new("Faraday error", { status: 500, body: {} })) }

      it "returns Failure" do
        expect(subject.send(:fetch_checkout_code)).to be_a(Dry::Monads::Failure)
      end
    end
  end

  describe "#validate_data" do
    context "when data is valid" do
      it "returns Success" do
        expect(subject.send(:validate_data, valid_response)).to eq(Success(valid_response[:data]))
      end
    end

    context "when status is false" do
      it "returns Failure" do
        expect(subject.send(:validate_data,
                            invalid_response.with_indifferent_access)).to eq(Failure("PayStack Status is not true"))
      end
    end

    context "when access_code or authorization_url is blank" do
      before { valid_response[:data][:access_code] = nil }

      it "returns Failure" do
        expect(subject.send(:validate_data,
                            valid_response.with_indifferent_access)).to eq(Failure("Paystack access_code or authorization_url is blank"))
      end
    end

    context "when reference key has changed" do
      before { valid_response[:data][:reference] = "another-uuid" }

      it "returns Failure" do
        expect(subject.send(:validate_data,
                            valid_response.with_indifferent_access)).to eq(Failure("Paystack reference key has changed"))
      end
    end
  end

  describe "#update_payment_transaction" do
    context "when update is successful" do
      before { allow(transaction).to receive(:update).and_return(true) }

      it "returns Success" do
        expect(subject.send(:update_payment_transaction, valid_response[:data])).to eq(Success(transaction))
      end
    end

    context "when update fails" do
      before do
        allow(transaction).to receive_messages(update: false, errors: double(full_messages: ["Error message"]))
      end

      it "returns Failure" do
        expect(subject.send(:update_payment_transaction, valid_response[:data])).to eq(Failure(["Error message"]))
      end
    end
  end

  describe "#perform" do
    context "when all steps are successful" do
      it "returns Success with reloaded transaction" do
        expect(subject.perform).to eq(Success(transaction))
      end
    end

    context "when any step fails" do
      before { allow(subject).to receive(:verify_transaction).and_return(Failure("Verification failed")) }

      it "returns Failure" do
        expect(subject.perform).to be_a(Dry::Monads::Failure)
      end
    end
  end
end
