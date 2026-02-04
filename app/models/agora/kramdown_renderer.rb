# frozen_string_literal: true

require "kramdown/converter/html"

module Agora
  class KramdownRenderer < Kramdown::Converter::Html
    def convert_header(el, indent)
      level = el.options[:level]
      classes = case level
      when 1
                  "text-3xl font-bold text-white mb-6 mt-8 border-b border-gray-800 pb-2"
      when 2
                  "text-2xl font-bold text-gray-200 mb-4 mt-6"
      when 3
                  "text-xl font-semibold text-gray-300 mb-3 mt-4"
      else
                  "text-lg font-medium text-gray-400 mb-2 mt-3"
      end

      el.attr["class"] = classes
      super
    end

    def convert_p(el, indent)
      el.attr["class"] = "text-gray-300 leading-relaxed mb-4 text-base"
      super
    end

    def convert_ul(el, indent)
      el.attr["class"] = "list-disc pl-6 mb-4 text-gray-300 space-y-2"
      super
    end

    def convert_ol(el, indent)
      el.attr["class"] = "list-decimal pl-6 mb-4 text-gray-300 space-y-2"
      super
    end

    def convert_blockquote(el, indent)
      el.attr["class"] = "border-l-4 border-indigo-500 pl-4 py-2 my-6 bg-gray-800/30 rounded-r italic text-gray-400"
      super
    end

    # We can override other elements if needed (table, etc.)
  end
end
