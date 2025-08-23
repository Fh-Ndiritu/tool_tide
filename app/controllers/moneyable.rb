# frozen_string_literal: true

module Moneyable
  extend ActiveSupport::Concern

  def from_subunit(amount)
    BigDecimal(amount) / 100
  end

  def to_subunit(amount)
    BigDecimal(amount) * 100
  end
end
