module Admin::MaskRequestsHelper
  def format_plant_name(full_name)
    name_parts = full_name.split("(", 2)
    english_name = name_parts[0].strip

    content_tag(:h4, class: "text-lg md:text-xl font-semibold text-secondary leading-tight") do
      output = english_name.html_safe

      if name_parts.size > 1
        # Re-add the opening parenthesis and strip any trailing space
        botanical_name = "(#{name_parts[1].strip}"

        botanical_span = content_tag(:span, botanical_name, class: "text-sm font-normal text-gray-500 block sm:inline-block ml-0 sm:ml-2")
        output += botanical_span
      end

      output
    end
  end
end
