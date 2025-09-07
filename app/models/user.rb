# frozen_string_literal: true

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
    return "" if address.blank?

    "#{address['state']}, #{address['country']}"
  end

  # You receive free credits to use with the free engine
  # For pro engine we need to monetize it so if you have received some before we can cut you off
  def issue_daily_credits
    ActiveRecord::Base.transaction do
      issue_free_engine_credits
      return if received_trial_credits?

      issue_trial_credits
    end
  end

  def received_daily_credits?
    received_daily_credits.in?(Time.zone.today.all_day)
  end

  def afford_generation?(landscape_request)
    case landscape_request.image_engine
    when "bria"
      free_engine_credits > 3 * BRIA_IMAGE_COST
    when "google"
      localization_cost = landscape_request.use_location? ? LOCALIZED_PLANT_COST : 0
      pro_access_credits >= (GOOGLE_IMAGE_COST * 3 + localization_cost)
    else
      false
    end
  end

  def charge_prompt_localization!
    charge_pro_cost!(LOCALIZED_PLANT_COST)
  end

  def charge_image_generation!(landscape_request)
    if landscape_request.google_processor?
      charge_pro_cost!(GOOGLE_IMAGE_COST * landscape_request.modified_images.size)
    else
      cost = BRIA_IMAGE_COST * landscape_request.modified_images.size
      update! free_engine_credits: [ 0, free_engine_credits - cost ].max
    end
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

  # We tell you are running low on premium credits, you can still user free engine or upgrade
  def schedule_downgrade_notification
    update!(reverted_to_free_engine: true, notified_about_pro_credits: false)
  end

  def complete_landscapes
    landscapes.joins(:landscape_requests).where(landscape_requests: { progress: [ :processed, :complete ] }).distinct
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
end
