module Agora
  class MarkdownRenderer < Redcarpet::Render::HTML
    def header(text, header_level)
      classes = case header_level
      when 1
        "text-3xl font-bold text-white mb-6 mt-8 border-b border-gray-800 pb-2"
      when 2
        "text-2xl font-bold text-gray-200 mb-4 mt-6"
      when 3
        "text-xl font-semibold text-gray-300 mb-3 mt-4"
      else
        "text-lg font-medium text-gray-400 mb-2 mt-3"
      end

      "<h#{header_level} class='#{classes}'>#{text}</h#{header_level}>"
    end

    def paragraph(text)
      "<p class='text-gray-300 leading-relaxed mb-4 text-base'>#{text}</p>"
    end

    def list(content, list_type)
      tag = list_type == :ordered ? "ol" : "ul"
      classes = list_type == :ordered ? "list-decimal" : "list-disc"
      "<#{tag} class='#{classes} pl-6 mb-4 text-gray-300 space-y-2'>#{content}</#{tag}>"
    end

    def list_item(content, list_type)
      "<li>#{content}</li>"
    end

    def blockquote(quote)
      "<blockquote class='border-l-4 border-indigo-500 pl-4 py-2 my-6 bg-gray-800/30 rounded-r italic text-gray-400'>#{quote}</blockquote>"
    end

    def table(header, body)
      "<div class='overflow-x-auto my-6 rounded-lg border border-gray-700'>" \
        "<table class='min-w-full divide-y divide-gray-700 bg-gray-800/50'>" \
          "<thead class='bg-gray-900'>#{header}</thead>" \
          "<tbody class='divide-y divide-gray-700'>#{body}</tbody>" \
        "</table>" \
      "</div>"
    end

    def table_row(content)
      "<tr>#{content}</tr>"
    end

    def table_cell(content, alignment)
      tag = content.include?("</th>") ? "th" : "td"
      classes = if tag == "th"
        "px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
      else
        "px-6 py-4 whitespace-nowrap text-sm text-gray-300"
      end
      "<#{tag} class='#{classes}'>#{content}</#{tag}>"
    end

    def codespan(code)
      "<code class='bg-gray-800 text-purple-300 px-1.5 py-0.5 rounded text-sm font-mono border border-gray-700'>#{code}</code>"
    end

    # Using default block_code handling but wrapping it if needed in CSS
  end
end
