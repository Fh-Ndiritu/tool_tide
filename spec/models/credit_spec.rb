# frozen_string_literal: true

require "rails_helper"

RSpec.describe Credit, type: :model do
  fixtures(:users)
  let(:user) { users(:john_doe) }

  describe "after_create_commit" do
    context "when credit is for pro_engine and purchase source" do
      it "increments user.pro_engine_credits" do
        expect do
          described_class.create(user: user, credit_type: :pro_engine, source: :purchase, amount: 10)
        end.to change { user.reload.pro_engine_credits }.by(10)
      end
    end
  end
end
