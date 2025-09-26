class TextRequest < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :user
  has_ancestry
  after_save_commit :generate_edit, if: :saved_change_to_prompt?
  after_update_commit :broadcast_progress, if: :saved_change_to_progress?

  default_scope -> { order(created_at: :desc) }


  scope :complete_or_in_progress, -> {
    where.not(progress: [ :uploading, :failed, :retrying ])
  }

  has_one_attached :original_image do |attachable|
    attachable.variant(:juxtaposed, resize_to_limit: [ 400, nil ])
  end

  has_one_attached :result_image do |attachable|
    attachable.variant(:juxtaposed, resize_to_limit: [ 400, nil ])
  end

  enum :progress, {
    uploading: 0,
    validating: 1,
    validated: 2,
    preparing: 3,
    generating: 4,
    processed: 5,
    complete: 6,
    failed: 7,
    retying: 8
  }

  enum :visibility, {
    personal: 0,
    everyone: 1
  }

  def in_progress?
    progress_before_type_cast.in?(self.class.progresses["validating"]...self.class.progresses["complete"])
  end

  private

  def generate_edit
    validating!
    TextEditorJob.perform_later(id)
  end

def broadcast_progress
  if failed? || complete?
    Turbo::StreamsChannel.broadcast_refresh_to("#{user.id}_text_requests")
  else
    Turbo::StreamsChannel.broadcast_update_to("#{user.id}_text_requests", target: "current_text_request", partial: "text_requests/form", locals: { text_request: self })
  end
end
end
