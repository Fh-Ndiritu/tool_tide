# frozen_string_literal: true

module ApplicationHelper
  def active_item(path)
    # this will make the current page active
    "active-item " if request.path == path
  end

  def progress_message(progress)
    case progress
    when "uploading"
      "Uploading Images"
    when "validating"
      "Validating drawing"
    when "validated"
      "Verified"
    when "preparing"
      "Preparing request"
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
    else
      "Loading ..."
    end
  end
end
