# frozen_string_literal: true
class LandscaperChannel < ApplicationCable::Channel
  def subscribed
    # TODO: we shall update this to be more specific later
    stream_from "landscaper_channel"
  end

  def unsubscribed
    # TODO: Any cleanup needed when channel is unsubscribed.
  end
end
