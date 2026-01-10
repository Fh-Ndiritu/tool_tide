class MaskRequest < ApplicationRecord
  include Designable
  include ActionView::RecordIdentifier



  has_many :plants, dependent: :destroy
  has_many :favorites, as: :favoritable, dependent: :destroy
  has_many :favorited_by_users, through: :favorites, source: :user

  has_one_attached :mask

  serialize :dimensions, coder: JSON
  store_accessor :preferences, :add_seating, :use_trees, :add_water, :use_location


  has_one_attached :main_view do |attachable|
    attachable.variant(:dashboard, resize_to_limit: [400, 400])
  end

  has_one_attached :rotated_view
  has_one_attached :drone_view

  has_one_attached :overlay

  belongs_to :canva
  delegate :image, to: :canva
  delegate :drawable_image, to: :canva
  delegate :user, to: :canva

  validate :preset_prompt, on: :update
  after_save_commit :mark_as_trial_generation, if: :saved_change_to_progress?
  after_update_commit :broadcast_progress, if: :saved_change_to_progress?
  default_scope -> { order(created_at: :desc) }

enum :progress, {
  uploading: 0,
  getting_location: 1,
  location_updated: 2,
  validating: 10,
  validated: 20,
  preparing: 30,
  main_view: 40,
  plants: 41,
  rotating: 50,
  drone: 60,
  processed: 70,
  complete: 8,
  failed: 90,
  retying: 100,
  mask_invalid: 110,
  overlaying: 120,
  fetching_plant_suggestions: 130,
  plant_suggestions_ready: 140
}

  enum :visibility, {
    personal: 0,
    everyone: 1
  }

  def purge_views
    main_view.purge
    rotated_view.purge
    drone_view.purge
  end

  def copy
    request = self.dup
    request.progress = :validated
    request.mask.attach mask.blob
    request.overlay.attach overlay.blob
    request.save!
    request
  end

  def dimensions
    drawable_image.metadata
  end

  def resize_mask
    api_image = MiniMagick::Image.read(canva.api_image_blob.download)
    mask_image = MiniMagick::Image.read(mask.blob.download)

    mask_image.resize "#{api_image.width}x#{api_image.height}!"

    mask_image.combine_options do |c|
      c.fuzz "10%" # Allow for slight variations in white
      c.transparent "white" # Make white transparent
    end


    # Create a new blob and attach it
    io_object = StringIO.new(mask_image.to_blob)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: io_object,
      filename: "final_mask.png",
      content_type: "image/png"
    )
    mask.attach(blob)
    save!
  end

  def overlay_mask
    api_image = MiniMagick::Image.read(canva.api_image_blob.download)

    mask_binary = mask.download
    mask_image = MiniMagick::Image.read(mask_binary)

    unless api_image.dimensions == mask_image.dimensions
      mask_image.resize "#{api_image.width}x#{api_image.height}!"
    end

    save_overlay(mask_image, api_image)
    save!
  end

  def face_image
    [ main_view.presence, rotated_view.presence, drone_view.presence ].compact.sample
  end

  def processing?
    plants? || getting_location? || location_updated? || validating? || preparing? || main_view? || plants? || rotating? || drone? || processed? || retying? || overlaying?
  end

  def fetching_plants?
    fetching_plant_suggestions? || plant_suggestions_ready?
  end

  def conclusive?
    complete? || failed?
  end

  def performing_plant_generation?
    fetching_plants? || (conclusive? && plants.present?)
  end

  private

  def broadcast_progress
    return if performing_plant_generation?

    Turbo::StreamsChannel.broadcast_refresh_to(canva)
  end

  def preset_prompt
    return unless preset.present?

    prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("landscape_presets", preset)
    errors.add(:preset, "does not exist") unless prompt.present?

    self.prompt = prompt
  end

  def save_overlay(mask_image, api_image)
    mask_image.combine_options do |c|
      c.transparent "white"  # Make white transparent
    end

    # Composite the mask over the target image
    masked_image = api_image.composite(mask_image) do |c|
      c.dissolve "70"  # Overlay the mask with 80% opacity
      c.gravity "Center" # Align the mask with the target image
    end

    blob = upload_blob(masked_image)

    overlay.attach(blob)
    save!
  end

  def mark_as_trial_generation
    return if trial_generation? || complete?

    unless user.has_purchased_credits_before?(created_at)
      update_column(:trial_generation, true)
    end
  end
end
