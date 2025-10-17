# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable

  has_many :payment_transactions, dependent: :destroy

  has_many :canvas, dependent: :destroy

  has_many :credits, dependent: :destroy
  has_many :text_requests, dependent: :destroy

  validates :privacy_policy, acceptance: { message: "must be accepted." }

  def state_address
    return "" if address.blank?

    "#{address['state']}, #{address['country']}"
  end

  def afford_generation?
    pro_engine_credits >= GOOGLE_IMAGE_COST * 3
  end

  def afford_text_editing?
    pro_engine_credits >= GOOGLE_IMAGE_COST
  end

  def charge_pro_cost!(cost)
   update! pro_engine_credits: [ 0, pro_engine_credits - cost ].max
  end

  def sufficient_pro_credits?
    # this means you can afford the next minimum pro cost
    pro_engine_credits >= GOOGLE_IMAGE_COST * DEFAULT_IMAGE_COUNT
  end

  private

  def received_trial_credits?
    credits.exists?(source: :trial, credit_type: :pro_engine)
  end
end
