class TextRequest < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :user
  has_ancestry

  has_many :favorites, as: :favoritable, dependent: :destroy
  has_many :favorited_by_users, through: :favorites, source: :user

  after_save_commit :generate_edit, if: :saved_change_to_prompt?
  after_update_commit :broadcast_progress, if: :saved_change_to_progress?

  default_scope -> { order(created_at: :desc) }
  before_save :mark_as_trial_generation, if: -> { progress_changed? && complete? }


  scope :complete_or_in_progress, -> {
    where.not(progress: [ :uploading, :failed, :retrying ])
  }

  has_one_attached :original_image do |attachable|
    attachable.variant(:juxtaposed, resize_to_limit: [ 700, nil ])
  end

  has_one_attached :result_image do |attachable|
    attachable.variant(:juxtaposed, resize_to_limit: [ 700, nil ])
  end

  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_admin, ->() { joins(:user).where(users: { admin: true }) }
  scope :by_visibility, ->(visibility) { where(visibility: visibility) }

  enum :progress, {
    uploading: 0,
    validating: 1,
    validated: 2,
    preparing: 3,
    generating: 4,
    processed: 5,
    complete: 6,
    failed: 7,
    retying: 8,
    analyzing: 9
  }

  enum :visibility, {
    personal: 0,
    everyone: 1
  }

  def in_progress?
    progress_before_type_cast.in?(self.class.progresses["validating"]...self.class.progresses["complete"]) || analyzing?
  end

  private

  def generate_edit
    validating!
    TextEditorJob.perform_later(id)
  end

  def broadcast_progress
    if failed? || complete?
      Turbo::StreamsChannel.broadcast_refresh_to(self)
    else
      Turbo::StreamsChannel.broadcast_update_to(self, target: dom_id(self, :loader), partial: "layouts/shared/loader", locals: { record: self, klasses: "group embed absolute !opacity-75 z-1 w-full h-full" })
    end
  end

  def mark_as_trial_generation
    unless user.has_purchased_credits_before?(created_at)
      update_column(:trial_generation, true)
    end
  end
end
