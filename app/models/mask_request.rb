class MaskRequest < ApplicationRecord
  include Designable
  include ActionView::RecordIdentifier

  has_one_attached :mask

  has_one_attached :main_view
  has_one_attached :rotated_view
  has_one_attached :drone_view

  has_one_attached :overlay

  belongs_to :canva
  delegate :image, to: :canva
  delegate :drawable_image, to: :canva
  delegate :user, to: :canva

  validate :preset_prompt, on: :update
  after_update_commit :broadcast_progress, if: :saved_change_to_progress?
  default_scope -> { order(created_at: :desc) }

  enum :progress, {
    uploading: 0,
    validating: 1,
    validated: 2,
    preparing: 3,
    main_view: 4,
    rotating: 5,
    drone: 6,
    processed: 7,
    complete: 8,
    failed: 9,
    retying: 10,
    mask_invalid: 11,
    overlaying: 12
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

  private

  def broadcast_progress
    if failed? || complete?
      Turbo::StreamsChannel.broadcast_refresh_to(canva, target: "styles")
    else
    Turbo::StreamsChannel.broadcast_replace_to(canva, target: "loader", partial: "layouts/shared/loader", locals: { record: self, klasses: "fixed " })
    end
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
      c.compose "Over"  # Overlay the mask
      c.gravity "Center" # Align the mask with the target image
    end

    blob = upload_blob(masked_image)

    overlay.attach(blob)
    save!
  end
end
