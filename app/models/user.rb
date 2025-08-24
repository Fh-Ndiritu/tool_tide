class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :landscapes, dependent: :destroy
  has_many :landscape_requests, through: :landscapes
  has_many :payment_transactions, dependent: :nullify
  has_many :credits, dependent: :destroy


  def state_address
    return "" unless address.present?

    "#{address['state']}, #{address['country']}"
  end

  # You receive free credits to use with the free engine
  # For pro engine we need to monetize it so if you have received some before we can cut you off
  def issue_daily_credits
    ActiveRecord::Base.transaction  do
      issue_free_engine_credits
      return if received_trial_credits?
      issue_trial_credits
    end
  end

  private

  def issue_free_engine_credits
    credits.create(source: :daily_issuance, amount: DAILY_FREE_ENGINE_CREDITS, credit_type: :free_engine)
    update received_daily_credits: true
  end

  def issue_trial_credits
    # these are used to demo to you how the pro engine works and are only 1 time tokenss
    credits.create!(source: :trial, amount: FIRST_USER_PRO_CREDITS, credit_type: :pro_engine)
  end

  def received_trial_credits?
    credits.exists?(source: :trial, credit_type: :pro_engine)
  end
end
