# frozen_string_literal: true

class PaymentTransaction < ApplicationRecord
  belongs_to :user, touch: true

  validates :uuid, :amount, presence: true

  before_validation :set_uuid, only: :create

  delegate :email, to: :user

  self.class.define_method :new_transaction do |user|
    create(
      user: user,
      amount: DEFAULT_USD_PURCHASE_AMOUNT
    )
  end

  # https://paystack.com/docs/payments/verify-payments/#transaction-statuses
  # the final status will be either success, failed, reversed or abandoned
  enum :status, {
    pending: 0,
    processing: 1,
    queued: 3,
    ongoing: 4,
    abandoned: 5,
    failed: 6,
    reversed: 7,
    success: 8
  }, prefix: :invoice

  def issue_credits
    return unless validated? && !credits_issued?

    ActiveRecord::Base.transaction do
      amount = Object.const_get("PRO_CREDITS_PER_#{currency}") * self.amount
      user.credits.create!(source: :purchase, amount:, credit_type: :pro_engine)
      update credits_issued: true
      user.update reverted_to_free_engine: false, notified_about_pro_credits: false
    end
  end

  private

  def set_uuid
    self.uuid = SecureRandom.hex(16)
  end
end
