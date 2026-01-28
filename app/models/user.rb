# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable, :omniauthable

  has_many :payment_transactions, dependent: :destroy

  has_many :canvas, dependent: :destroy
  has_many :credit_vouchers, dependent: :destroy
  has_many :mask_requests, through: :canvas
  has_one :onboarding_response, dependent: :destroy
  has_one :project_onboarding, dependent: :destroy
  has_one :user_setting, dependent: :destroy
  delegate :default_model, :default_variations, to: :user_setting_with_fallback


  has_many :credits, dependent: :destroy
  has_many :credit_spendings, dependent: :destroy
  has_many :text_requests, dependent: :destroy
  has_many :sketch_requests, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :received_favorites, class_name: "Favorite", as: :favoritable, dependent: :destroy

  has_many :projects, dependent: :destroy
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

  # Credits are now issued after onboarding survey completion
  # after_create_commit :issue_signup_credits
  after_create_commit :schedule_welcome_follow_up
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
    pro_engine_credits >= GOOGLE_PRO_IMAGE_COST * 3
  end

  def afford_text_editing?
    pro_engine_credits >= GOOGLE_PRO_IMAGE_COST
  end

  def charge_pro_cost!(cost)
   update! pro_engine_credits: [ 0, pro_engine_credits - cost ].max
  end

  def sufficient_pro_credits?
    # this means you can afford the next minimum pro cost
    pro_engine_credits >= GOOGLE_PRO_IMAGE_COST * DEFAULT_IMAGE_COUNT
  end

  def can_afford_generation?(model_alias, count = 1)
    cost_per_image = MODEL_COST_MAP[model_alias] || GOOGLE_PRO_IMAGE_COST
    pro_engine_credits >= cost_per_image * count
  end

  def can_skip_onboarding_survey?
    # you can skip if you completed questions or received credits prior to implementation
    onboarding_response&.completed? || credits.exists?
  end

  def redacted_email
    email
    email[0..5] = "*" * 5
    email
  end

  def has_purchased_credits_before?(time = nil)
    if time
      credits.where(source: :purchase).where("created_at <= ?", time).exists?
    else
      credits.where(source: :purchase).exists?
    end
  end

  def signup_credits
    credits.signup.first&.amount || 0
  end

  def issue_signup_credits
    return if credits.where(source: :signup).exists?

    credits.create!(
      source: :signup,
      credit_type: :pro_engine,
      amount: TRIAL_CREDITS
    )
  end

  def first_name
    if name.present?
      name.split(" ").first
    end
  end

  def user_setting_with_fallback
    user_setting || create_user_setting(default_model: "pro_mode", default_variations: 2)
  end

  def resumable_request
    # Find a mask request that is stuck in validating (saved but not generated)
    # created recently, and we now have credits to run it.
    return nil unless afford_generation?

    mask_requests.where(progress: :validating)
                 .where("mask_requests.created_at > ?", 2.days.ago)
                 .includes(:main_view_attachment)
                 .find { |mr| !mr.main_view.attached? }
  end

  private



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

  def schedule_welcome_follow_up
    WelcomeFollowUpJob.set(wait: 1.hour).perform_later(id)
  end
end
