# frozen_string_literal: true

require "kramdown"
require "kramdown/converter/html"

module Agora
  class TestRenderer < Kramdown::Converter::Html
    def convert_p(el, indent)
      font_size = @options[:font_class] || "text-base"
      el.attr['class'] = "text-gray-300 #{font_size}"
      super
    end
  end
end

text = "Hello world"

# Test 1: Default
doc1 = Kramdown::Document.new(text, input: "GFM")
out1 = Agora::TestRenderer.convert(doc1.root, doc1.options).first
puts "Default: #{out1}"

# Test 2: Custom Option
# Note: Kramdown::Document.new might filter options.
# We need to see if we can pass it, or if we modify options passed to convert.
options = { input: "GFM", font_class: "text-xs" }
# Kramdown::Document only accepts known options?
# Using a hack: modify the options hash passed to convert.
doc2 = Kramdown::Document.new(text, input: "GFM")
custom_options = doc2.options.merge(font_class: "text-xs")

out2 = Agora::TestRenderer.convert(doc2.root, custom_options).first
puts "Custom: #{out2}"
