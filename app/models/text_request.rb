class TextRequest < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :user
  has_ancestry
  after_update_commit :generate_edit, if: :saved_change_to_prompt?
  after_update_commit :broadcast_progress, if: :saved_change_to_progress?

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

  private

  def generate_edit
    TextEditor.perform(self)
  end

def broadcast_progress
  if failed? || complete?
    Turbo::StreamsChannel.broadcast_refresh_to(self)
  else
    Turbo::StreamsChannel.broadcast_replace_to(self, target: "loader", partial: "layouts/shared/loader", locals: { record: self })
  end
end
end
