# frozen_string_literal: true

module ApplicationHelper
  # include Pagy::Frontend - removed for v43
  def active_item(path)
    # this will make the current page active
    "active-item " if request.path == path
  end

  def active_link_class(path)
    base_classes = "block px-4 py-3 text-sm rounded-lg transition duration-150 group font-medium"
    if current_page?(path)
      "#{base_classes} bg-[#ce219a]/75 text-white is-active"
    else
      "#{base_classes} text-neutral-900 hover:bg-[#ce219a]/75 hover:text-white"
    end
  end

  def marketing_link_class(path)
    base_classes = "px-2 py-1.5 text-sm font-medium rounded-lg transition-colors duration-200"
    if current_page?(path)
      "#{base_classes} bg-[#ce219a]/75 text-white font-bold"
    else
      "#{base_classes} text-black hover:bg-[#ce219a]/75 hover:text-white"
    end
  end

  def progress_message(progress)
    case progress
    when "uploading"
      "Uploading Image"
    when "getting_location"
      "Getting your location..."
    when "location_updated"
      "Location updated!"
    when "fetching_plant_suggestions"
      "Fetching plant suggestions..."
    when "plant_suggestions_ready"
      "Plant suggestions ready!"
    when "validating"
      "Validating image"
    when "validated"
      "Verified"
    when "preparing", "overlaying"
      "Preparing request"
    when "generating"
      "Editing Image"
    when "main_view"
      "Curating the Main View"
    when "plants"
      "Suggesting plants"
    when "rotating"
      "Making a second option"
    when "drone"
      "Curating option 3"
    when "processed"
      "Processed"
    when "complete"
      "Done"
    when "failed"
      "Failed"
    when "retrying"
      "Retrying"
    when "mask_invalid"
      "Invalid Drawing"
    when "overlaying"
      "Analyzing Garden Area"
    else
      "Just a moment 🧘"
    end
  end

  def markdown(text, font_class: "text-base")
    return "" if text.blank?

    doc = Kramdown::Document.new(
      text,
      input: "GFM",
      syntax_highlighter: nil,
      hard_wrap: true
    )

    options = doc.options.merge(font_class: font_class)
    Agora::KramdownRenderer.convert(doc.root, options).first.html_safe
  end

  def strip_markdown(text)
    return "" if text.blank?
    # Simple strategy: render to HTML (handling strict newlines), then strip tags
    # preventing tag collapsing by adding newlines
    html = markdown(text)
    # Using a simple replacements for common block tags to preserve spacing
    html = html.gsub("</p>", "\n\n").gsub("<br>", "\n").gsub("</li>", "\n")
    strip_tags(html).strip
  end
end
