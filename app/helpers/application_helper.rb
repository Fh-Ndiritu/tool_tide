# frozen_string_literal: true

module ApplicationHelper
  def active_item(path)
    # this will make the current page active
    "active-item " if request.path == path
  end

  def progress_message(progress)
    case progress
    when "uploading"
      "Uploading Image"
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
      "Rotating Camera Angle"
    when "drone"
      "Generating DJI drone view"
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
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: "nofollow", target: "_blank" },
      space_after_headers: true,
      fenced_code_blocks: true
    }

    extensions = {
      autolink: true,
      superscript: true,
      disable_indented_code_blocks: true,
      tables: true
    }

    renderer = Redcarpet::Render::HTML.new(options)
    markdown = Redcarpet::Markdown.new(renderer, extensions)

    markdown.render(text).html_safe
  end
end
