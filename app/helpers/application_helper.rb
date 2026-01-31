# frozen_string_literal: true

module ApplicationHelper
  def active_item(path)
    # this will make the current page active
    "active-item " if request.path == path
  end

  def active_link_class(path)
    base_classes = "block px-4 py-3 text-sm rounded-lg transition duration-150 group"
    if current_page?(path)
      "#{base_classes} bg-accent/10 text-accent"
    else
      "#{base_classes} text-gray-700 hover:bg-accent/10 hover:text-accent"
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

  def markdown(text)
    options = {
      filter_html: false, # Allow some HTML if needed, but renderer handles most
      hard_wrap: true,
      link_attributes: { rel: "nofollow", target: "_blank", class: "text-indigo-400 hover:text-indigo-300 underline" },
      space_after_headers: true,
      fenced_code_blocks: true
    }

    extensions = {
      autolink: true,
      superscript: true,
      disable_indented_code_blocks: true,
      tables: true,
      strikethrough: true,
      highlight: true,
      fenced_code_blocks: true
    }

    renderer = Agora::MarkdownRenderer.new(options)
    markdown = Redcarpet::Markdown.new(renderer, extensions)

    markdown.render(text.to_s).html_safe
  end
end
