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

  validate :preset_prompt, on: :update

  after_update_commit :generate_designs, if: :saved_change_to_preset?
  after_update_commit :broadcast_progress, if: :saved_change_to_progress?

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
    mask_invalid: 11
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

  private

  def broadcast_progress
    Turbo::StreamsChannel.broadcast_replace_to(dom_id(canva), target: "loader", partial: "layouts/shared/loader", locals: { mask_request: self })
  end

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
end
