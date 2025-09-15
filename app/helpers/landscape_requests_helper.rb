# frozen_string_literal: true

module LandscapeRequestsHelper
  def image_label(index)
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
