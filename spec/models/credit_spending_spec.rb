require 'rails_helper'

RSpec.describe CreditSpending, type: :model do
  let(:user) { users(:one) }
  let(:layer) { project_layers(:one) }

  it "is valid with valid attributes" do
    spending = CreditSpending.new(user: user, amount: 8, transaction_type: :spend, trackable: layer)
    expect(spending).to be_valid
  end

  it "is invalid without an amount" do
    spending = CreditSpending.new(amount: nil)
    expect(spending).not_to be_valid
  end

  it "is invalid with amount <= 0" do
    spending = CreditSpending.new(user: user, amount: 0, transaction_type: :spend, trackable: layer)
    expect(spending).not_to be_valid
  end

  it "belongs to a trackable polymorphic association" do
    spending = CreditSpending.create!(user: user, amount: 8, transaction_type: :spend, trackable: layer)
    expect(spending.trackable).to eq(layer)
  end
end
