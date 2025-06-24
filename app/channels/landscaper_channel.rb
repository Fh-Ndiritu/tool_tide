class LandscaperChannel < ApplicationCable::Channel
  def subscribed
   stream_from "landscaper_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
