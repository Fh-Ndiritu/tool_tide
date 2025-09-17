# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :payment_transactions, dependent: :destroy

  has_many :canvas

  has_many :credits, dependent: :destroy

  def state_address
    return "" if address.blank?

    "#{address['state']}, #{address['country']}"
  end

  # You receive free credits to use with the free engine
  # For pro engine we need to monetize it so if you have received some before we can cut you off
  def issue_daily_credits
    ActiveRecord::Base.transaction do
      return if received_trial_credits?

      issue_trial_credits
    end
  end

  def afford_generation?
    pro_access_credits >= (GOOGLE_IMAGE_COST * 3)
  end

  def pro_access_credits
    pro_engine_credits + pro_trial_credits
  end

  def charge_pro_cost!(cost)
    if pro_trial_credits >= cost
      update! pro_trial_credits: [ 0, pro_trial_credits - cost ].max
    else
      balance = cost - pro_trial_credits
      update! pro_engine_credits: [ 0, pro_engine_credits - balance ].max, pro_trial_credits: 0
    end
  end

  def sufficient_pro_credits?
    # this means you can afford the next minimum pro cost
    pro_engine_credits >= GOOGLE_IMAGE_COST * DEFAULT_IMAGE_COUNT
  end

  private

  def issue_trial_credits
    # these are used to demo to you how the pro engine works and are only 1 time tokenss
    credits.create!(source: :trial, amount: PRO_TRIAL_CREDITS, credit_type: :pro_engine)
  end

  def received_trial_credits?
    credits.exists?(source: :trial, credit_type: :pro_engine)
  end
end
