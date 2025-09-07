# frozen_string_literal: true

module LandscapeHelper
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
    when "generating_images"
      "Creating Landscapes"
    when "saving_results"
      "Saving Designs"
    when "processed"
      "Processed"
    when "complete"
      "Done"
    when "failed"
      "Failed"
    end
  end
end
