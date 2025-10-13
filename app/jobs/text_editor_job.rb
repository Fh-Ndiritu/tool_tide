class TextEditorJob < ApplicationJob
  queue_as :default

  delegate :perform, to: "TextEditor"
end
