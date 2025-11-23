# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "#credits_purchased_email" do
    let(:user) { double("User", email: "test@example.com") }
    let(:transaction) do
      double("PaymentTransaction",
        amount: 10.0,
        paypal_order_id: "ORDER-123ABC",
        paypal_payer_id: "PAYER-456DEF",
        status: "success",
        paid_at: Time.zone.parse("2025-01-15 14:30:00")
      )
    end
    let(:credits_issued) { 100 }
    let(:mail) do
      UserMailer.with(
        user: user,
        transaction: transaction,
        credits_issued: credits_issued
      ).credits_purchased_email
    end

    it "renders the headers" do
      expect(mail.subject).to eq("Your Credits Purchase is Complete! 🎉")
      expect(mail.to).to eq([ user.email ])
    end

    it "renders the body with user email" do
      expect(mail.body.encoded).to include("Hello #{user.email}!")
    end

    it "renders the body with Francis signature" do
      expect(mail.body.encoded).to include("Francis from Hadaa AI here")
      expect(mail.body.encoded).to include("Best,")
      expect(mail.body.encoded).to include("Francis")
    end

    it "includes the credits amount" do
      expect(mail.body.encoded).to include("#{credits_issued} credits")
    end

    it "includes order details" do
      expect(mail.body.encoded).to include("ORDER-123ABC")
      expect(mail.body.encoded).to include("$10.00 USD")
      expect(mail.body.encoded).to include("100 credits")
      expect(mail.body.encoded).to include("January 15, 2025")
      expect(mail.body.encoded).to include("PayPal")
    end

    it "includes link to design editor" do
      expect(mail.body.encoded).to include("Go to Design Editor")
    end

    context "with different credits amount" do
      let(:credits_issued) { 500 }

      it "displays the correct credits amount" do
        expect(mail.body.encoded).to include("500 credits")
      end
    end

    context "with different transaction amount" do
      let(:transaction) do
        double("PaymentTransaction",
          amount: 50.0,
          paypal_order_id: "ORDER-789XYZ",
          status: "success",
          paid_at: Time.current
        )
      end

      it "displays the correct amount" do
        expect(mail.body.encoded).to include("$50.00 USD")
        expect(mail.body.encoded).to include("ORDER-789XYZ")
      end
    end
  end
end
