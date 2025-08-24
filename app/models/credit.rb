class Credit < ApplicationRecord
  belongs_to :user
  after_create_commit :update_user_credits
  enum :source, {
    daily_issuance: 0,
    trial: 1,
    purchase: 2
  }

  enum :credit_type, {
    free_engine: 0,
    pro_engine: 1
  }

  private

  def update_user_credits
    if pro_engine?
      user.increment!(:pro_engine_credits, amount)
    else
      user.increment!(:free_engine_credits, amount)
    end
  end
end
