# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentTransaction, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  #  describe 'validations' do
  #   it { should validate_presence_of(:amount)}
  #   it { should validate_presence_of(:reference_id)}
  #  end
end
