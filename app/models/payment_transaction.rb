class PaymentTransaction < ApplicationRecord
  belongs_to :user, touch: true

  validates_presence_of :uuid, :amount

  before_validation :set_uuid, only: :create

  delegate :email, to: :user

  def subunit_amount
    amount * 100
  end
  private

  def set_uuid
    self.uuid = SecureRandom.hex(16)
  end
end
