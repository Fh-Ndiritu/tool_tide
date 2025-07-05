class LandscapeChannel < ApplicationCable::Channel
  def subscribed
   stream_from "landscape_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
