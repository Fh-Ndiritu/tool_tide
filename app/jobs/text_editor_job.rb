class TextEditorJob < ApplicationJob
  queue_as :generation
  retry_on StandardError, attempts: 3
  delegate :perform, to: "TextEditor"
end
