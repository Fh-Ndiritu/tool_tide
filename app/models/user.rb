# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable, :omniauthable

  has_many :payment_transactions, dependent: :destroy

  has_many :canvas, dependent: :destroy
  has_many :mask_requests, through: :canvas

  has_many :credits, dependent: :destroy
  has_many :text_requests, dependent: :destroy
  has_many :favorites, as: :favoritable, dependent: :destroy

  validates :privacy_policy, acceptance: { message: "must be accepted." }

  enum :source, {
    email: 0,
    google: 1
  }

  enum :onboarding_stage, {
    fresh: 0,
    welcome_seen: 1,
    image_uploaded: 2,
    mask_drawn: 3,
    style_selected: 8,
    plants_viewed: 9,
    first_result_viewed: 4,
    text_editor_opened: 5,
    refinement_generated: 6,
    completed: 7
  }

  geocoded_by :current_sign_in_ip do |obj, results|
    if geo = results.first
      obj.latitude = geo.latitude
      obj.longitude = geo.longitude
      obj.address = {
        city: geo.city,
        state: geo.state,
        country: geo.country,
        country_code: geo.country_code
      }
    end
  end

  before_save :geocode
  # , if: ->(obj) { obj.current_sign_in_ip.present? && obj.current_sign_in_ip_changed? }

  after_create_commit :issue_signup_credits

  def state_address
    return "" if address.blank?

    "#{address['state']}, #{address['country']}"
  end

  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.password = Devise.friendly_token[0, 20]
      user.name = auth.info.name
      user.privacy_policy = true
      user.source = "google"
    end
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

  def redacted_email
    email
    email[0..5] = "*" * 5
    email
  end

  private

  def issue_signup_credits
    credits.create!(
      source: :signup,
      credit_type: :pro_engine,
      amount: 40
    )
  end
end
