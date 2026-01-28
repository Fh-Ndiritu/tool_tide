class CreditVoucher < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :user, presence: true
  validates :amount, numericality: { greater_than: 0 }

  def redeem?
    with_lock do
      return false if redeemed_at.present?

      update!(redeemed_at: Time.current)
      user.credits.create!(
        source: :voucher,
        credit_type: :pro_engine,
        amount: amount
      )
      true
    end
  end
end
