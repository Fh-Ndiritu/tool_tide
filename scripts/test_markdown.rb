# frozen_string_literal: true

require "kramdown"
require "kramdown-parser-gfm"

text = <<~MARKDOWN
  # Header 1
  ## Header 2
  This is a paragraph.
  This line should be on a new line if hard_wrap is working.

  This is a new paragraph.
MARKDOWN

helper = Class.new do
  def markdown(text)
    doc = Kramdown::Document.new(
      text,
      input: "GFM",
      syntax_highlighter: nil,
      hard_wrap: true
    )
    Agora::KramdownRenderer.convert(doc.root, doc.options).first
  end
end.new

puts "--- INPUT ---"
puts text
puts "\n--- OUTPUT ---"
puts helper.markdown(text)
