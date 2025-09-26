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
    when "preparing"
      "Preparing request"
    when "generating"
      "Editing Image"
    when "main_view"
      "Curating the Main View"
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
end
