# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentTransaction, type: :model do
  let(:user) { User.create!(email: "test@example.com", password: "password123", password_confirmation: "password123") }

  describe "#issue_credits" do
    let(:transaction) do
      PaymentTransaction.create!(
        user: user,
        amount: 10.0,
        currency: "USD",
        validated: true,
        credits_issued: false,
        paypal_order_id: "ORDER-123",
        status: :success
      )
    end

    before do
      # Stub the constant for credits calculation
      stub_const("PRO_CREDITS_PER_USD", 10)
    end

    context "when transaction is validated and credits not yet issued" do
      it "creates credits for the user" do
        expect {
          transaction.issue_credits
        }.to change { user.credits.count }.by(1)
      end

      it "calculates the correct credits amount" do
        transaction.issue_credits
        credit = user.credits.last
        expect(credit.amount).to eq(100) # 10 USD * 10 credits per USD
        expect(credit.source).to eq("purchase")
        expect(credit.credit_type).to eq("pro_engine")
      end

      it "marks credits as issued" do
        expect {
          transaction.issue_credits
        }.to change { transaction.reload.credits_issued }.from(false).to(true)
      end

      it "updates user flags" do
        user.update!(reverted_to_free_engine: true, notified_about_pro_credits: true)

        transaction.issue_credits
        user.reload

        expect(user.reverted_to_free_engine).to be false
        expect(user.notified_about_pro_credits).to be false
      end

      it "sends confirmation email" do
        expect {
          transaction.issue_credits
        }.to have_enqueued_mail(UserMailer, :credits_purchased_email)
          .with(
            params: {
              user: user,
              transaction: transaction,
              credits_issued: 100
            },
            args: []
          )
      end

      it "returns the credits amount" do
        credits_amount = transaction.issue_credits
        expect(credits_amount).to eq(100)
      end

      context "with different amount" do
        let(:transaction) do
          PaymentTransaction.create!(
            user: user,
            amount: 50.0,
            currency: "USD",
            validated: true,
            credits_issued: false,
            paypal_order_id: "ORDER-456",
            status: :success
          )
        end

        it "calculates credits correctly" do
          credits_amount = transaction.issue_credits
          expect(credits_amount).to eq(500) # 50 USD * 10 credits per USD
        end

        it "sends email with correct credits amount" do
          expect {
            transaction.issue_credits
          }.to have_enqueued_mail(UserMailer, :credits_purchased_email)
            .with(
              params: hash_including(credits_issued: 500),
              args: []
            )
        end
      end
    end

    context "when transaction is not validated" do
      let(:transaction) do
        PaymentTransaction.create!(
          user: user,
          amount: 10.0,
          validated: false,
          credits_issued: false
        )
      end

      it "does not create credits" do
        expect {
          transaction.issue_credits
        }.not_to change { user.credits.count }
      end

      it "does not send email" do
        expect {
          transaction.issue_credits
        }.not_to have_enqueued_mail(UserMailer, :credits_purchased_email)
      end

      it "returns nil" do
        expect(transaction.issue_credits).to be_nil
      end
    end

    context "when credits already issued" do
      let(:transaction) do
        PaymentTransaction.create!(
          user: user,
          amount: 10.0,
          validated: true,
          credits_issued: true,
          paypal_order_id: "ORDER-789",
          status: :success
        )
      end

      it "does not create credits again" do
        expect {
          transaction.issue_credits
        }.not_to change { user.credits.count }
      end

      it "does not send email again" do
        expect {
          transaction.issue_credits
        }.not_to have_enqueued_mail(UserMailer, :credits_purchased_email)
      end

      it "returns nil" do
        expect(transaction.issue_credits).to be_nil
      end
    end

    context "when transaction fails during credit creation" do
      before do
        allow(user.credits).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it "rolls back the transaction" do
        expect {
          transaction.issue_credits rescue nil
        }.not_to change { transaction.reload.credits_issued }
      end

      it "does not send email" do
        expect {
          transaction.issue_credits rescue nil
        }.not_to have_enqueued_mail(UserMailer, :credits_purchased_email)
      end
    end
  end
end
