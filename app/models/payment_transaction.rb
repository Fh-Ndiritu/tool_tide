class PaymentTransaction < ApplicationRecord
  belongs_to :user, touch: true

  validates_presence_of :uuid, :amount

  before_validation :set_uuid, only: :create

  delegate :email, to: :user

  self.class.define_method :new_transaction do |user|
    create(
      user: user,
      amount: 20.00
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

  private

  def set_uuid
    self.uuid = SecureRandom.hex(16)
  end
end
