class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :landscapes, dependent: :destroy
  has_many :landscape_requests, through: :landscapes
  has_many :payment_transactions, dependent: :destroy

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

  def received_daily_credits?
    received_daily_credits.in?(Date.today.all_day)
  end

  def afford_generation?(landscape_request)
    case landscape_request.image_engine
    when :bria
      free_engine_credits >  3 * BRIA_IMAGE_COST
    when :google
      localization_cost = landscape_request.use_localization? ? LOCALIZED_PLANT_COST : 0
      pro_engine_credits > (GOOGLE_IMAGE_COST * 3 + localization_cost)
    else
      false
    end
  end

  def charge_prompt_localization?
    update! pro_engine_credits: [ 0, pro_engine_credits - LOCALIZED_PLANT_COST ].max
  end

  def charge_image_generation?(landscape_request)
    if landscape_request.google_processor?
      update! pro_engine_credits: [ 0, pro_engine_credits - GOOGLE_IMAGE_COST ].max
    else
      update! free_engine_credits: [ 0, free_engine_credits - BRIA_IMAGE_COST ].max
    end
  end

  private

  def issue_free_engine_credits
    credits.create(source: :daily_issuance, amount: DAILY_FREE_ENGINE_CREDITS, credit_type: :free_engine)
    update received_daily_credits: Time.zone.now, free_engine_credits: 0
  end

  def issue_trial_credits
    # these are used to demo to you how the pro engine works and are only 1 time tokenss
    credits.create!(source: :trial, amount: PRO_TRIAL_CREDITS, credit_type: :pro_engine)
  end

  def received_trial_credits?
    credits.exists?(source: :trial, credit_type: :pro_engine)
  end

    def nullify_payment_transactions
    self.payment_transactions.update_all(user_id: nil)
  end
end
