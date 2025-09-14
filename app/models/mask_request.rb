class MaskRequest < ApplicationRecord
  include Designable
  has_one_attached :mask
  has_one_attached :final_mask

  has_one_attached :main_view
  has_one_attached :rotated_view
  has_one_attached :drone_view

  has_one_attached :responsive_image
  has_one_attached :overlay

  belongs_to :canva
  delegate :image, to: :canva

  validate :preset_prompt, on: :update
  after_update_commit :generate_designs, if: :saved_change_to_preset?

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
    retying: 10
  }

  def purge_views
    main_view.purge
    rotated_view.purge
    drone_view.purge
  end

  def validate_mask
    update!(error_msg: nil, progress: :validating)
    update(error_msg: "permitted_errors.missing_drawing") unless mask.attached?
    resize_mask
    # 5% must be painted
    threshold = 5

    update(error_msg: "permitted_errors.missing_drawing") if painted_percentage < threshold
    purge_views
    overlay_mask
    validated!
  end

  private

  def preset_prompt
    return unless preset.present?

    prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("landscape_presets", preset)
    errors.add(:preset, "does not exist") unless prompt.present?

    self.prompt = prompt
  end

  def generate_designs
    return unless mask.attached?
    DesignGenerator.perform(self)
  end

  def overlay_mask
    original_image = MiniMagick::Image.read(image.blob.download)

    mask_binary = mask.download
    mask_image = MiniMagick::Image.read(mask_binary)

    unless original_image.dimensions == mask_image.dimensions
      mask_image.resize "#{original_image.width}x#{original_image.height}!"
    end

    save_overlay(mask_image, original_image)
    save!
  end


  def save_overlay(mask_image, original_image)
    mask_image.combine_options do |c|
      c.colorspace("Gray")
      c.threshold("50%")
    end

    mask_image.transparent("white")

    masked_image = original_image.composite(mask_image) do |c|
      c.compose "Over"
    end

    blob = upload_blob(masked_image)

    overlay.attach(blob)
  end


  def resize_mask
    original_image = MiniMagick::Image.read(image.blob.download)
    mask_file = MiniMagick::Image.read(mask.blob.download)
    return if original_image.dimensions == mask_file.dimensions

    mask_file.resize "#{original_image.width}x#{original_image.height}!"
    io_object = StringIO.new(mask_file.to_blob)

    blob = ActiveStorage::Blob.create_and_upload!(
      io: io_object,
      filename: "final_mask.png",
      content_type: "image/png"
    )
    mask.attach(blob)
    save!
    blob
  end

  def painted_percentage
    image = MiniMagick::Image.read(mask.download)
    gray_image = image.colorspace("Gray").threshold("50%")

    mean = gray_image.data.dig("channelStatistics", "gray", "mean")
    max = gray_image.data.dig("channelStatistics", "gray", "max")

    return 0 unless mean

   # Max will be 1 or 255 while mean at 0 means all black while at 1/255 means all white
   (max - mean).to_f / max * 100
  end
end
