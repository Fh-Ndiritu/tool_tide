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
  has_many :sketch_requests, dependent: :destroy
  has_many :favorites, as: :favoritable, dependent: :destroy

  validates :privacy_policy, acceptance: { message: "must be accepted." }, on: :create

  enum :source, {
    email: 0,
    google: 1
  }

  before_update :prevent_onboarding_regression, if: :will_save_change_to_onboarding_stage?

  enum :onboarding_stage, {
    fresh: 0,
    welcome_seen: 10,
    image_uploaded: 20,
    mask_drawn: 30,
    style_selected: 40,
    plants_viewed: 50,
    first_result_viewed: 60,
    text_editor_opened: 70,
    refinement_generated: 80,
    completed: 90
  }

  before_save :geocode_ip, if: :will_save_change_to_current_sign_in_ip?

  def geocode_ip
    return unless current_sign_in_ip.present?

    if geo = LocationService.lookup(current_sign_in_ip)
      self.latitude = geo.latitude
      self.longitude = geo.longitude
      self.address = {
        city: geo.city,
        state: geo.state,
        country: geo.country,
        country_code: geo.country_code
      }
    end
  end

  after_create_commit :issue_signup_credits

  def location_city
    return nil if address.blank?
    address["city"]
  end

  def last_design_date
    [
      mask_requests.maximum(:created_at),
      text_requests.maximum(:created_at),
      sketch_requests.maximum(:created_at)
    ].compact.max
  end

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

  enum :restart_onboarding_status, {
    initial: 0,
    restarted: 1,
    completed_after_restart: 2
  }

  def prevent_onboarding_regression
    return if onboarding_stage.nil?

    old_value = changes_to_save["onboarding_stage"]&.first
    return if old_value.nil?

    old_int = self.class.onboarding_stages[old_value]
    new_int = self.class.onboarding_stages[self.onboarding_stage]

    # Clamp to max between prev and current
    if new_int < old_int
      self.onboarding_stage = old_value
    end
  end
end
