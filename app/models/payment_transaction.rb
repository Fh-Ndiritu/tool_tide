class PaymentTransaction < ApplicationRecord
  belongs_to :user, touch: true

  validates_presence_of :reference_id, :amount

  before_validation :set_reference_id, only: :create

  private

  def set_reference_id
    self.reference_id = SecureRandom.hex(16)
  end

end
