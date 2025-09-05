# frozen_string_literal: true

module LandscapeRequestsHelper
  def progress_message(progress)
    case progress
    when "uploading"
      "Uploading Images"
    when "validating_drawing"
      "Validating drawing"
    when "suggesting_plants"
      "Suggesting local plants"
    when "preparing_request"
      "Preparing request"
    when "generating_landscape"
      "Creating Landscapes"
    when "changing_angles"
      "Changing Camera Angle"
    when "generating_drone_view"
      "Generating DJI drone view"
    when "saving_results"
      "Saving Designs"
    when "processed"
      "Processed"
    when "complete"
      "Done"
    when "failed"
      "Retrying"
    end
  end

  def image_label(engine, index)
    return "4k Download" if engine != 'google'

    case index
    when 0
      "Main View"
    when 1
      "Rotated Camera View"
    when 2
      "Drone shot angle"
    else
      "HD result"
    end
  end
end
