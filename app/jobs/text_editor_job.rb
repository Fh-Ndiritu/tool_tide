class TextEditorJob < ApplicationJob
  queue_as :default
  retry_on StandardError, attempts: 3
  delegate :perform, to: "TextEditor"
end
