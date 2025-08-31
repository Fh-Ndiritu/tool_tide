class LandscapeRequest < ApplicationRecord
  validates :preset, :image_engine, :prompt, presence: { on: :update }

  belongs_to :landscape
  has_many_attached :modified_images
  has_one_attached :mask_image_data
  has_one_attached :partial_blend
  has_one_attached :full_blend

  enum :image_engine, { bria: 0, google: 1 }, suffix: :processor
  delegate :user, to: :landscape

  has_many :suggested_plants, dependent: :destroy

  scope :unclaimed, -> { where(preset: nil, image_engine: :bria, prompt: nil) }

  enum :progress, {
    uploading: 0,
    validating_drawing: 1,
    suggesting_plants: 2,
    preparing_request: 3,
    generating_images: 4,
    saving_results: 5,
    processed: 6,
    complete: 7,
    failed: 100
  }

  def recommend_flowers
    return unless use_location?
    return if suggested_plants.present?

    fetch_plant_response.content.each do |suggestion|
      suggested_plants.create!(suggestion)
    end
  end

  def build_localized_prompt!
    return false unless user.afford_generation?(self)

    ActiveRecord::Base.transaction do
      suggested_plants.destroy_all
      recommend_flowers
      if suggested_plants.present? && preset.present?
        response = fetch_localization_prompt
        update! localized_prompt: response.content["updated_prompt"]
        user.charge_prompt_localization!
      else
        false
      end
    end
  end

  def set_default_image_processor!
    # if the user has pro_engine_credits, that are enough, we assign them to google
    # else we go with BRIA
    localization_cost = use_location? ? LOCALIZED_PLANT_COST : 0
    google_cost = DEFAULT_IMAGE_COUNT * GOOGLE_IMAGE_COST + localization_cost
    image_engine = if user.pro_access_credits >= google_cost
                     :google
                   else
                     :bria
                   end

    update! image_engine: image_engine
  end

  def full_prompt
    localized_prompt.presence || prompt
  end

  private

  def fetch_plant_response
    chat = RubyLLM.chat
    chat.with_schema(SUGGESTED_PLANTS_SCHEMA).ask(
      "Recommend 7 flowers and plants that would be ideal for a front yard garden located in #{user.state_address}.
      The plants need to be perfect for a cottage style design yet easy to shop around #{user.state_address}.
      Once you have identified the flowers, include a short description of how they will look in their best form.
      This should together define the look of the garden.
      The description will look like:
      <example_description>
        fiery orange and red Japanese quince flowers
      <example_description>
    "
    )
  end

  def fetch_localization_prompt
    chat = RubyLLM.chat
    chat.with_schema(LOCALIZED_PROMPT_SCHEMA).ask(
      "You shall be given an extract from a larger prompt used to generate a landscape design for a garden.
       Your job is to update the prompt so that it uses the new plants and flowers provided instead of those in the prompt.
       You shall update the name of flowers and how they look.
       Then return the new prompt as updated prompt
       <prompt_extract>
       #{PROMPTS['landscape_presets'][preset.downcase]}
       </prompt_extract>

       <plants_and_flowers>
       #{suggested_plants.pluck(:name).join(',')}
       </plants_and_flowers>

       DO NOT change any other part of the prompt, or provide any commentary.
    "
    )
  end
end
