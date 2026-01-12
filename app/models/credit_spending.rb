class CreditSpending < ApplicationRecord
  belongs_to :user
  belongs_to :trackable, polymorphic: true

  enum :transaction_type, {
    spend: 0,
    refund: 1,
    adjustment: 2
  }

  validates :amount, numericality: { greater_than: 0 }
end
