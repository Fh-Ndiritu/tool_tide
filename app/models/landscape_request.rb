class LandscapeRequest < ApplicationRecord
  validates_presence_of :preset, :image_engine, :prompt, on: :update

  belongs_to :landscape
  has_many_attached :modified_images

  has_many :active_storage_attachments, class_name: 'ActiveStorage::Attachment', as: :record

  enum :image_engine, [ :bria, :google ], suffix: :processor
  delegate :ip_address, to: :landscape
  delegate :user, to: :landscape

  has_many :suggested_plants, dependent: :destroy

  scope :unclaimed, -> { where(preset: nil, image_engine: :bria, prompt: nil) }

  def recommend_flowers?
    return false unless authorized_to_recommend_flowers?

    response = fetch_plant_response

    response.content.each do  |suggestion|
      suggested_plants.create!(suggestion)
    end

    true
  end

  def build_localized_prompt?
    return false unless authorized_to_localize_prompt?

    response = fetch_localization_prompt
    self.update localized_prompt: response.content['updated_prompt']
  end

  private

  def authorized_to_recommend_flowers?
    suggested_plants.blank? && use_location?
  end

  def authorized_to_localize_prompt?
    suggested_plants.present? && use_location? && preset.present?
  end

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
    ")
  end


  def fetch_localization_prompt
    chat = RubyLLM.chat
    chat.with_schema(LOCALIZED_PROMPT_SCHEMA).ask(
      "You shall be given an extract from a larger prompt used to generate a landscape design for a garden.
       Your job is to update the prompt so that it uses the new plants and flowers provided instead of those in the prompt.
       You shall update the name of flowers and how they look.
       Then return the new prompt as updated prompt
       <prompt_extract>
       #{PROMPTS["landscape_presets"][preset.downcase]}
       </prompt_extract>

       <plants_and_flowers>
       #{suggested_plants.pluck(:name).join(',')}
       </plants_and_flowers>

       DO NOT change any other part of the prompt, or provide any commentary.
    ")
  end
end
